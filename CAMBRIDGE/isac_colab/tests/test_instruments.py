"""Hardware-free protocol, transaction and fresh-record regression tests."""
import contextlib
import io
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import numpy as np
from isac import instruments as ins
from isac.common import signature, load_record
from tests.common import get_config


class RawDevice:
    def __init__(self,idn='Keysight Technologies,M8195A,MOCK,1'):
        self.read_termination='\n'; self.write_termination='\n'; self.commands=[]
        self.raw_writes=[]; self.pending=b''; self.closed=False; self.idn=idn
        self.short_write=False; self.fail_query=False; self.terminations=[]
    def query(self,command):
        self.commands.append(command)
        if self.fail_query: raise TimeoutError('injected')
        return self.idn if command=='*IDN?' else '0,"No error"'
    def write(self,command): self.commands.append(command)
    def write_raw(self,data):
        self.raw_writes.append(data)
        return len(data)-int(self.short_write)
    def read_bytes(self,count,break_on_termchar=True):
        self.terminations.append((self.read_termination,break_on_termchar))
        data,self.pending=self.pending[:count],self.pending[count:]
        return data
    def close(self): self.closed=True


class Manager:
    def __init__(self,devices): self.devices=list(devices); self.closed=False
    def open_resource(self,address): return self.devices.pop(0)
    def close(self): self.closed=True


class AWG:
    def __init__(self):
        self.commands=[]; self.running=True; self.closed=False; self.output=1
        self.vpp=1.; self.divider='DIV4'; self.reference_clock='INT'; self.memory=np.array([],dtype=np.int8)
        self.segment=1; self.writes=0; self.fail_write=0
    def query(self,c):
        self.commands.append(('query',c))
        responses={'*IDN?':'Keysight Technologies,M8195A,MOCK,1','*OPT?':'004,16G',
            '*OPC?':'1',':SYSTem:ERRor?':'0,"No error"',':FUNCtion:MODE?':'ARB',
            ':INSTrument:DACMode?':'FOUR',':INSTrument:MEMory:EXTended:RDIVider?':self.divider,
            ':FREQuency:RASTer?':'64000000000',':ROSCillator:SOURce?':self.reference_clock,
            ':VOLTage1:AMPLitude?':str(self.vpp),':VOLTage1:OFFSet?':'0',
            ':TRACe1:SELect?':str(self.segment),':INITiate:CONTinuous?':'1',
            ':INITiate:CONTinuous:ENABle?':'SELF',':INITiate:GATE?':'0'}
        if c in responses: return responses[c]
        for ch in range(1,5):
            if c==f':OUTPut{ch}?': return str(self.output if ch==1 else 0)
            if c==f':TRACe{ch}:MMODe?': return 'EXT' if ch==1 else 'INT'
            if c==f':TRACe{ch}:CATalog?': return f'{self.segment},{self.memory.size}' if self.memory.size else '0,0'
            if c==f':TRACe{ch}:FREE?': return '4294967296,0,4294967296'
        if c.startswith(':TRACe1:DATA?'):
            if self.running: raise RuntimeError('Unsupported running waveform read')
            segment,offset,count=map(int,c.split(' ',1)[1].split(','))
            return ','.join(map(str,self.memory[offset:offset+count]))
        raise RuntimeError('Unmocked AWG query '+c)
    def send(self,c):
        self.commands.append(('send',c))
        if c==':ABORt': self.running=False
        elif c==':INITiate:IMMediate': self.running=True
        elif c==':OUTPut1 ON': self.output=1
        elif c==':OUTPut1 OFF': self.output=0
        elif c.startswith(':TRACe1:DEFine '):
            self.segment,n=map(int,c.split(' ',1)[1].split(',')); self.memory=np.zeros(n,dtype=np.int8)
        elif c.startswith(':TRACe1:DELete '): self.memory=np.array([],dtype=np.int8)
        elif c.startswith(':TRACe1:SELect '): self.segment=int(c.split(' ')[1])
        elif c not in (':FUNCtion:MODE ARB',':INITiate:CONTinuous 1',':INITiate:CONTinuous:ENABle SELF',':INITiate:GATE 0'):
            raise RuntimeError('Unmocked AWG send '+c)
    def write_block(self,prefix,data):
        self.commands.append(('write',prefix)); self.writes+=1
        if self.writes==self.fail_write: raise RuntimeError('Injected upload failure')
        _,offset=map(int,prefix.split(' ',1)[1].strip(',').split(','))
        self.memory[offset:offset+len(data)]=data
    def read_block(self,c,datatype,n,maxn):
        self.commands.append(('read',c))
        if self.running: raise RuntimeError('Unsupported running backup')
        _,offset,count=map(int,c.split(' ',1)[1].split(','))
        return self.memory[offset:offset+count].copy()
    def close(self): self.closed=True


class Scope:
    def __init__(self,n=400000,fs=5e6):
        self.commands=[];self.closed=False;self.n=n;self.fs=fs;self.timebase=.01
        self.raw=(20000+np.arange(n)%1000).astype(np.uint16)
    def query(self,c):
        self.commands.append(('query',c))
        values={'*IDN?':'AGILENT TECHNOLOGIES,MSO-X 4154A,MOCK,1','*OPC?':'1',
            ':SYSTem:ERRor?':'0,"No error"',':TIMebase:MODE?':'MAIN',':TIMebase:SCALe?':str(self.timebase),
            ':WAVeform:FORMat?':'WORD',':WAVeform:BYTeorder?':'LSBF',':WAVeform:UNSigned?':'1',
            ':WAVeform:PREamble?':f'1,0,{self.n},1,{1/self.fs:.17g},-0.04,0,0.000002,0.12,20000'}
        return values[c]
    def send(self,c):
        self.commands.append(('send',c))
        if c.startswith(':TIMebase:SCALe '): self.timebase=float(c.split(' ')[1])
    def read_block(self,c,datatype,n,maxn):
        self.commands.append(('read',c)); return self.raw.copy()
    def close(self): self.closed=True


def fixture(folder,n=400000,fs=5e6):
    cfg=get_config();cfg['upload_chunk_samples']=640
    plan=dict(toneTileSamplesAWG=256,toneTotalRepeats=2,toneSamplesAWG=512,
              ofdmFrameSamplesAWG=640,communicationFrames=4,totalSamplesAWG=3072,
              waveformBytes=3072,cycleDuration_s=3072/16e9,minimumCaptureDuration_s=.0675344)
    exp=dict(config=cfg,cfg={'toneFrequencyHz':500e3,'FsAWG':16e9},packet={},plan=plan)
    exp['signature']=signature(exp)
    awg,scope=AWG(),Scope(n,fs);awg.memory=np.zeros(3072,dtype=np.int8)
    rig=ins.Rig(awg,scope,cfg)
    rig.last_transmission=dict(signature=exp['signature'],sessionId=rig.session_id,
                              idn='Keysight Technologies,M8195A,MOCK,1',segment=1,totalSamples=3072,
                              previousSettings={'referenceClock':'INT'})
    return cfg,exp,rig,awg,scope


class InstrumentTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup)
        self.silence=contextlib.redirect_stdout(io.StringIO());self.silence.__enter__()
        self.addCleanup(self.silence.__exit__,None,None,None)
    def test_constructor_failure_closes_open_resource(self):
        d=RawDevice()
        with self.assertRaisesRegex(RuntimeError,'timeout must be positive'):
            ins.Transport(d,'MOCK',0)
        self.assertTrue(d.closed)

    def test_transport_binary_exact_and_termination(self):
        d=RawDevice();t=ins.Transport(d,'MOCK',12.5)
        self.assertEqual(d.timeout,12500)
        codes=np.array([-128,-1,0,10,13,35,127],dtype=np.int8)
        t.write_block(':D ',codes)
        self.assertEqual(d.raw_writes[0],b':D #17'+bytes([128,255,0,10,13,35,127])+b'\n')
        d.pending=b'#18'+bytes([0,10,13,35,127,128,255,1])+b'\r\n'
        out=t.read_block(':WAV?','uint16',4,4)
        np.testing.assert_array_equal(out,[2560,8973,32895,511])
        self.assertEqual(d.read_termination,'\n')
        self.assertTrue(all(x==(None,False) for x in d.terminations))
    def test_transport_errors_restore_and_close(self):
        d=RawDevice();t=ins.Transport(d,'MOCK',2)
        d.pending=b'#14x'
        with self.assertRaisesRegex(RuntimeError,'Short binary read'):t.read_block(':D?','int8',4)
        self.assertEqual(d.read_termination,'\n')
        d.pending=b'#210'
        with self.assertRaisesRegex(RuntimeError,'Announced binary size'):t.read_block(':D?','int8',2)
        d.short_write=True
        with self.assertRaisesRegex(RuntimeError,'Short binary write'):t.write_block(':D ',np.zeros(2,dtype=np.int8))
        t.close();t.close();self.assertTrue(d.closed)
        with self.assertRaisesRegex(RuntimeError,'closed'):t.query('*IDN?')
    def test_connect_no_output_and_failure_cleanup(self):
        cfg=get_config();a=RawDevice();s=RawDevice('AGILENT,MSO-X 4154A,TEST,0');rm=Manager([a,s])
        rig=ins.connect(cfg,rm)
        self.assertEqual(a.commands,['*IDN?',':SYSTem:ERRor?']);self.assertFalse(rm.closed)
        rig.close();self.assertTrue(a.closed and s.closed)
        a=RawDevice();s=RawDevice('WRONG');rm=Manager([a,s])
        with self.assertRaisesRegex(RuntimeError,'Scope address'):ins.connect(cfg,rm)
        self.assertTrue(a.closed and s.closed)
    def test_capture_without_tx_and_mutation_rejected_before_io(self):
        _,exp,rig,awg,scope=fixture(self.tmp.name);rig.last_transmission=None
        with self.assertRaisesRegex(RuntimeError,'successfully before capture'):ins.capture(rig,exp)
        self.assertFalse(awg.commands or scope.commands);self.assertFalse(rig.busy)
        exp['config']['pilot_measurement_s']=.02
        with self.assertRaisesRegex(ValueError,'changed'):ins.capture(rig,exp)
        self.assertFalse(awg.commands or scope.commands)
    def test_capture_no_running_memory_read_exact_scaling(self):
        _,exp,rig,awg,scope=fixture(self.tmp.name)
        c=ins.capture(rig,exp)
        self.assertTrue(c['validForProcessing']);self.assertEqual(c['FsCapture'],5e6)
        np.testing.assert_allclose(c['YData'],(scope.raw.astype(float)-20000)*2e-6+.12)
        self.assertEqual(c['XData'][0],-.04);self.assertAlmostEqual(c['durationSeconds'],399999/5e6)
        self.assertTrue(all(action=='query' and ':DATA' not in cmd for action,cmd in awg.commands))
        self.assertLess(scope.commands.index(('send',':DIGitize CHANnel1')),scope.commands.index(('send',':WAVeform:FORMat WORD')))
        np.testing.assert_array_equal(c['codes'],scope.raw);self.assertFalse(rig.busy)
    def test_capture_invalid_rate_and_span_are_flagged(self):
        for n,fs,reason in [(200000,2e6,'rate'),(200000,5e6,'span')]:
            with self.subTest(reason=reason):
                _,exp,rig,_,_=fixture(self.tmp.name,n,fs)
                with self.assertWarns(UserWarning):c=ins.capture(rig,exp)
                self.assertFalse(c['validForProcessing']);self.assertIn(reason,c['validationError'])
                self.assertEqual(c['codes'].size,n)
    def test_changed_physical_settings_invalidate_tx(self):
        _,exp,rig,awg,scope=fixture(self.tmp.name);awg.vpp=.5
        with self.assertRaisesRegex(RuntimeError,'voltage changed'):ins.capture(rig,exp)
        self.assertIsNone(rig.last_transmission);self.assertFalse(scope.commands)
    def test_changed_reference_clock_blocks_capture_before_scope(self):
        _,exp,rig,awg,scope=fixture(self.tmp.name)
        awg.reference_clock='EXT'
        with self.assertRaisesRegex(RuntimeError,'reference clock changed'):
            ins.capture(rig,exp)
        self.assertIsNone(rig.last_transmission)
        self.assertFalse(scope.commands)
        self.assertFalse(rig.busy)
        self.assertTrue(all(action=='query' and ':DATA' not in command
                            for action,command in awg.commands))

    def test_upload_backups_readback_before_playback(self):
        _,exp,rig,awg,_=fixture(self.tmp.name)
        old=np.arange(320,dtype=np.int16).astype(np.int8);awg.memory=old.copy()
        frame=np.arange(640,dtype=np.int16).astype(np.int8)
        with patch('isac.modem.awg_frame',return_value=frame):tx=ins.transmit(rig,exp,Path(self.tmp.name))
        self.assertTrue(awg.running);self.assertEqual(awg.output,1);self.assertIsNotNone(rig.last_transmission)
        np.testing.assert_array_equal(np.fromfile(tx['backup']['records'][0]['path'],dtype=np.int8),old)
        np.testing.assert_array_equal(awg.memory[512:],np.tile(frame,4))
        start=awg.commands.index(('send',':INITiate:IMMediate'))
        for i,(action,command) in enumerate(awg.commands):
            if ':DATA?' in command or ':DATA:BLOCk?' in command:self.assertLess(i,start)
        self.assertTrue(Path(tx['savedPath']).is_file())
    def test_upload_one_frame_readback_stays_in_record(self):
        _,exp,rig,awg,_=fixture(self.tmp.name)
        exp['plan'].update(communicationFrames=1,totalSamplesAWG=1152,
                           waveformBytes=1152,cycleDuration_s=1152/16e9)
        exp['signature']=signature(exp)
        with patch('isac.modem.awg_frame',return_value=np.zeros(640,dtype=np.int8)):
            tx=ins.transmit(rig,exp,Path(self.tmp.name))
        self.assertTrue(awg.running)
        self.assertTrue(all(offset+128 <= 1152 for offset in tx['spotOffsets']))
        self.assertEqual(awg.memory.size,1152)

    def test_identical_waveform_is_reused_without_backup_or_upload(self):
        _,exp,rig,awg,_=fixture(self.tmp.name)
        frame=np.arange(640,dtype=np.int16).astype(np.int8)
        with patch('isac.modem.awg_frame',return_value=frame):
            first=ins.transmit(rig,exp,Path(self.tmp.name)/'a')
            self.assertFalse(first['reused'])
            loaded=awg.memory.copy();awg.commands=[]
            tx=ins.transmit(rig,exp,Path(self.tmp.name)/'b')
        self.assertTrue(tx['reused']);self.assertEqual(tx['backup']['records'],[])
        self.assertFalse(any(a in ('write','read') or 'DEFine' in c or 'DELete' in c for a,c in awg.commands))
        np.testing.assert_array_equal(awg.memory,loaded)
        self.assertTrue(awg.running);self.assertEqual(awg.output,1);self.assertIsNotNone(rig.last_transmission)
        self.assertTrue(Path(tx['savedPath']).is_file())
    def test_different_waveform_is_backed_up_and_replaced(self):
        _,exp,rig,awg,_=fixture(self.tmp.name)
        awg.memory=np.ones(3072,dtype=np.int8)
        frame=np.arange(640,dtype=np.int16).astype(np.int8)
        with patch('isac.modem.awg_frame',return_value=frame):tx=ins.transmit(rig,exp,Path(self.tmp.name))
        self.assertFalse(tx['reused']);self.assertEqual(len(tx['backup']['records']),1)
        np.testing.assert_array_equal(np.fromfile(tx['backup']['records'][0]['path'],dtype=np.int8),np.ones(3072))
        np.testing.assert_array_equal(awg.memory[512:],np.tile(frame,4))
    def test_upload_failure_stops_and_invalidates(self):
        _,exp,rig,awg,_=fixture(self.tmp.name);awg.fail_write=2
        with patch('isac.modem.awg_frame',return_value=np.zeros(640,dtype=np.int8)):
            with self.assertRaisesRegex(RuntimeError,'Injected upload failure'):ins.transmit(rig,exp,Path(self.tmp.name))
        self.assertFalse(awg.running);self.assertEqual(awg.output,0)
        self.assertIsNone(rig.last_transmission);self.assertFalse(rig.busy)
    def test_chunk_crosses_tone_and_frame_boundaries(self):
        p=dict(toneTileSamplesAWG=2,toneSamplesAWG=4,toneTotalRepeats=2,ofdmFrameSamplesAWG=3,communicationFrames=2,totalSamplesAWG=10)
        out=ins.arb_chunk(np.array([1,2],dtype=np.int8),np.array([-1,-2,-3],dtype=np.int8),p,3,6)
        np.testing.assert_array_equal(out,[2,-1,-2,-3,-1,-2])
    def test_stop_disconnect_session_cleanup(self):
        _,_,rig,awg,scope=fixture(self.tmp.name)
        ins.disconnect(rig)
        self.assertFalse(rig.connected or awg.running);self.assertEqual(awg.output,0)
        self.assertTrue(awg.closed and scope.closed);self.assertIsNone(rig.last_transmission)

if __name__=='__main__':unittest.main()
