# Lab07 Matrix Multiplication with Clock Domain Crossing
This lab will accomplish a simple matrix multiplication which size is [16,1] x [1,16] = [16,16]. The important part is that the interface module and computation module will be implemented in different clock domain, so this lab requires to build syncronizer as a bridge between two module.

There will be handshake syncronizer from interface to computation module.

The other synchronizer from computation to interface module will be FIFO synchronizer while the storage in the FIFO will be SRAM compiled from memory compiler, which will only be shown as functional block here in the code.\

This code also required to manually verify the code with Jasper CDC, and the assertion is provided.
