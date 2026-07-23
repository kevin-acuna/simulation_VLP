***Linea A***: Beam-steered single-LED OWP

Una arquitectura mínima de OWP puede localizar en 3D con un solo LED orientable y un solo PD, pero para ser útil en la práctica debe ser broadcast, experimentalmente validada y robusta a patrones ópticos no ideales.

1. Experimental validation of model-based beam-steered single-LED/single-PD 3D OWP for 6G localization. (journal)
2. Broadcast Beam-Steered Single-LED Optical Wireless Positioning for Multi-User Indoor 6G Systems [LETTER]
3. ***Physics-Informed Calibration for Beam-Steered Single-LED Optical Wireless Positioning o Physics-Informed Transfer Learning for Robust Beam-Steered Optical Wireless Positioning under Optical Channel Mismatch o Inter-Laboratory Physics-Informed Adaptation for Robust Beam-Steered Optical Wireless Positioning***
    1. Nota: El enfoque no debe ser vender el paper como 3D OWP usando PINN. Sino vender la problematica que resolveria PINN.
    2. Pensar bien en la problematica que está resolviendo.

Linea B: Beyond Lambertian LED: VCSEL / Gaussian beams / codebook design

1. Localization-Oriented Gaussian Beam Codebook Design for VCSEL-Based Optical Wireless Systems [TCOM JOURNAL]

Los sistemas ópticos 6G tenderán a usar haces más estrechos, direccionales y adaptativos. Eso cambia el problema de localización: ya no basta estimar posición; hay que diseñar el haz, el codebook y el mecanismo de steering. (Keywords: **OWC + beam management + positioning/sensing).**

1. ***Experimental Demonstration of Machine-Learning-Assisted Liquid-Lens Laser Beam Control for Optical Wireless Positioning (Journal)***

Finalmente mi narrativa es: 

Beam-steered optical wireless positioning for 6G indoor systems: from model-based single-LED localization, to broadcast multi-user operation, to next-generation Gaussian/VCSEL beam codebook design.


Paper	Pregunta científica central	Prioridad
A0 TCOM	¿Cuál es el límite y el estimador óptimo para 3D OWP con single beam-steered LED/single PD?	0
A1 Broadcast letter	¿Puede un codebook común localizar múltiples usuarios sin medición personalizada K+1?	3
A2 Experimental journal	¿Qué tan bien funciona el modelo bajo imperfecciones reales de canal y hardware?	1
A3 Physics-informed calibration	¿Cómo cerrar la brecha entre modelo ideal y medición real con pocos datos de calibración?	4
B1 VCSEL Gaussian codebook	¿Cómo diseñar haces Gaussianos estrechos para balancear cobertura, precisión y overhead?	2
B2 Liquid lens	¿Puede un front-end óptico adaptativo controlar el haz experimentalmente para mejorar OWP/OWC?	5