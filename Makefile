CC      ?= gcc
CFLAGS  ?= -O2 -Wall -Wextra -Wno-unused-parameter -Wno-sign-compare
SRCS     = main.c lexer.c parser.c codegen.c module.c
OBJS     = $(SRCS:.c=.o)
TARGET   = velc

.PHONY: all clean install test

all: $(TARGET)

$(TARGET): $(OBJS)
	$(CC) $(CFLAGS) -o $@ $^

%.o: %.c velocity.h
	$(CC) $(CFLAGS) -c -o $@ $<

install: $(TARGET)
	install -m 755 $(TARGET) /usr/local/bin/vel
	@echo "Installed vel to /usr/local/bin/vel"
	@if [ -d stdlib ]; then \
		mkdir -p /usr/local/lib/velocity/stdlib; \
		cp -r stdlib/* /usr/local/lib/velocity/stdlib/; \
		echo "Installed stdlib to /usr/local/lib/velocity/stdlib/"; \
	fi

clean:
	rm -f $(OBJS) $(TARGET) *.asm *.o

test: $(TARGET)
	@echo "=== Running Velocity v0.3.0 capability tests ==="
	@for f in tests/*.vel; do \
		echo "[TEST] $$f"; \
		./vel $$f -o /tmp/_vl_test && /tmp/_vl_test; \
		echo "  exit: $$?"; \
	done
