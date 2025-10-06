# AArch64_macos_CSPRNG
An Arc4Random based prng written entirely in ARM64 on MacOS. After cloning the project, you can run the precompiled version from the bin directory with the command<br>
`./random (number_of_bytes)`


## Compilation
the project includes a makefile which creates an executable file for MacOS in the bin directory, because this program is written to target MacOS its system call invocations will prevent compatibility with any other platform.

## Functionality
the program is based on the arc4random cryptographically secure pseudo random number generator (CSPRNG). It uses a system call to gather the OS' entropy for the key and nonce to a SIMD implementation of the ChaCha20 block function. Any desired random lengths longer than 64 bytes simply call the ChaCha20 block function again with an incremented counter, much like in the actual encryption use case. When the desired length is met, the program prints the output to the console as a hexadecimal number.