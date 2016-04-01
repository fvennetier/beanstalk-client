OS := $(shell uname)

SOURCES1    := $(wildcard test/*.cc)
SOURCES2    := $(wildcard examples/c/*.c)
SOURCES3    := $(wildcard examples/cpp/*.cc)
TESTS       := $(SOURCES1:%.cc=%)
CEXAMPLES   := $(SOURCES2:%.c=%)
CPPEXAMPLES := $(SOURCES3:%.cc=%)
DESTDIR      = /
PREFIX       = usr
INCLUDEDIR   = $(PREFIX)/include/
MACHINE     := $(shell uname -m)
ifeq ($(MACHINE), x86_64)
LIBDIR       = $(PREFIX)/lib64
else
LIBDIR       = $(PREFIX)/lib
endif
PKGCONFIGDIR = $(LIBDIR)/pkgconfig/

VERSION      = $(shell cat beanstalk.h | grep BS_.*_VERSION | sed 's/^.*VERSION *//' | xargs echo | sed 's/ /./g')

ifeq ($(OS), Darwin)
SHAREDLIB    = libbeanstalk.dylib
LINKER       = -shared -Wl,-dylib_install_name,$(SHAREDLIB).1
LNOPTS       = -sf
else
SHAREDLIB    = libbeanstalk.so
LINKER       = -shared -Wl,-soname,$(SHAREDLIB).1
LNOPTS       = -sfT
endif

STATICLIB    = libbeanstalk.a
CFLAGS       = -Wall -Wno-sign-compare -g -I.
LDFLAGS      = -L. -lbeanstalk
CC           = gcc
CPP          = g++

all: $(CEXAMPLES) $(CPPEXAMPLES) benchmark

test: $(TESTS)
	test/run-all

$(TESTS): test/%:test/%.o $(SHAREDLIB)
	$(CPP) -o $@ $< $(LDFLAGS) -lgtest -lpthread

test/%.o: test/%.cc
	$(CPP) $(CFLAGS) -c -o $@ $<

benchmark: benchmark.cc $(SHAREDLIB)
	$(CPP) $(CFLAGS) -o benchmark benchmark.cc $(LDFLAGS) -lpthread

$(CEXAMPLES): examples/c/%:examples/c/%.o $(SHAREDLIB)
	$(CC) -o $@ $< $(LDFLAGS)

examples/c/%.o: examples/c/%.c
	$(CC) $(CFLAGS) -c -o $@ $<

$(CPPEXAMPLES): examples/cpp/%:examples/cpp/%.o $(SHAREDLIB)
	$(CPP) -o $@ $< $(LDFLAGS)

examples/cpp/%.o: examples/cpp/%.cc
	$(CPP) $(CFLAGS) -c -o $@ $<

$(STATICLIB): beanstalk.o beanstalkcpp.o
	rm -f $@
	ar -cq $@ $^

$(SHAREDLIB): beanstalk.o beanstalkcpp.o
	$(CPP) $(LINKER) -o $(SHAREDLIB)  beanstalk.o beanstalkcpp.o

beanstalk.o: beanstalk.c beanstalk.h makefile
	$(CC) $(CFLAGS) -fPIC -c -o beanstalk.o beanstalk.c

beanstalkcpp.o: beanstalk.cc beanstalk.hpp makefile
	$(CPP) $(CFLAGS) -fPIC -c -o beanstalkcpp.o beanstalk.cc

install: $(SHAREDLIB) $(STATICLIB)
	install -d $(DESTDIR)$(INCLUDEDIR)
	install beanstalk.h $(DESTDIR)$(INCLUDEDIR)
	install beanstalk.hpp $(DESTDIR)$(INCLUDEDIR)

	install -d $(DESTDIR)$(LIBDIR)
	install -m 0644 $(SHAREDLIB) $(DESTDIR)$(LIBDIR)/$(SHAREDLIB).$(VERSION)
	ln $(LNOPTS) $(SHAREDLIB).$(VERSION) $(DESTDIR)$(LIBDIR)/$(SHAREDLIB).1
	ln $(LNOPTS) $(SHAREDLIB).$(VERSION) $(DESTDIR)$(LIBDIR)/$(SHAREDLIB)

	install -m 0644 $(STATICLIB) $(DESTDIR)$(LIBDIR)/$(STATICLIB).$(VERSION)
	ln $(LNOPTS) $(STATICLIB).$(VERSION) $(DESTDIR)$(LIBDIR)/$(STATICLIB).1
	ln $(LNOPTS) $(STATICLIB).$(VERSION) $(DESTDIR)$(LIBDIR)/$(STATICLIB)

	install -d $(DESTDIR)$(PKGCONFIGDIR)
	install beanstalk-client.pc $(DESTDIR)$(PKGCONFIGDIR)/libbeanstalk.pc
	sed -i -e 's/@VERSION@/$(VERSION)/' $(DESTDIR)$(PKGCONFIGDIR)/libbeanstalk.pc
	sed -i -e 's,@prefix@,$(PREFIX),' $(DESTDIR)$(PKGCONFIGDIR)/libbeanstalk.pc
	sed -i -e 's,@libdir@,$(LIBDIR),' $(DESTDIR)$(PKGCONFIGDIR)/libbeanstalk.pc
	sed -i -e 's,@includedir@,$(INCLUDEDIR),' $(DESTDIR)$(PKGCONFIGDIR)/libbeanstalk.pc

uninstall:
	rm -f $(DESTDIR)$(INCLUDEDIR)/beanstalk.h
	rm -f $(DESTDIR)$(INCLUDEDIR)/beanstalk.hpp
	rm -f $(DESTDIR)$(LIBDIR)$(SHAREDLIB)*
	rm -f $(DESTDIR)$(LIBDIR)$(STATICLIB)*
	rm -f $(DESTDIR)$(PKGCONFIGDIR)/libbeanstalk.pc

clean:
	rm -f *.o *.so *.so.* $(STATICLIB) test/test[0-9] test/*.o examples/**/*.o examples/**/example?
