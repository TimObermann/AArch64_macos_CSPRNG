CC = as
LD = ld
ARCH = arm64
SDK = $(shell xcrun --sdk macosx --show-sdk-path)

TARGET = bin/random
SOURCES = src/randomGen.s

$(TARGET): $(SOURCES)
	$(CC) -arch $(ARCH) -o $(TARGET).o $<
	$(LD) -arch $(ARCH) -o $@ $(TARGET).o -lSystem -syslibroot $(SDK)
	chmod +x $@

run: $(TARGET)
	./$(TARGET) $(ARGS)

clean:
	rm -f $(TARGET) *.o

.PHONY: run clean