# Lab04 Convolution Neural Network
Implemented a CNN (Convolutional Neural Network) with 32-bit IEEE floating-point operations, processing 4×4 resolution images with 3 channels. The computation is performed using an IEEE floating-point IP. Note that the computation IP is synchronized at 02_syn. Since the IP is confidential, it is only presented as a functional block.
The CNN network is shown in the below figure:

(1.) Padding is available with zero padding or replication padding.
(2.) Convolution is fixed with stride 1, filter size 3x3
(3.) Normalizaion is Min-Max Normalization
(4.) Activation is available with Sigmoid, Tanh, Soft plus or ReLU
