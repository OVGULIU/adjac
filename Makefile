FC=gfortran
CXX=g++

CXXFLAGS=-g -O3
FFLAGS=-g -O3
#FFLAGS=-ggdb -Og

TESTS=$(patsubst %.f95,%.test,$(wildcard tests/test_*.f95)) $(patsubst %.f95,%.test_pure,$(wildcard tests/test_*.f95))
EXAMPLES=$(patsubst %.f95,%,$(wildcard examples/*.f95))
CXXEXAMPLES=$(patsubst %.cpp,%,$(wildcard examples/*.cpp))

ADOLC_CFLAGS=-I/usr/include/adolc
ADOLC_LIBS=-ladolc
ADEPT_CFLAGS=-Iadept-1.0/include
ADEPT_LIBS=-Ladept-1.0/lib -ladept
CPPAD_CFLAGS=$(shell pkg-config --cflags cppad)
CPPAD_LIBS=$(shell pkg-config --libs cppad)

all: examples test libadjac.a

examples: $(EXAMPLES)

test: $(TESTS)
	@rm -f tests/*.out; \
	ok=0; \
	for t in $(TESTS); do \
		b="`basename $$t`"; \
		c="tests/$$b.cmp"; \
		log="$$t.out"; \
		echo "--------------------------------------------" > "$$log"; \
		echo "$$b" >> "$$log"; \
		echo "--------------------------------------------" >> "$$log"; \
		echo -n "$$b... "; ./$$t >> "$$log" 2>&1; \
		result=$$?; \
		if test "$$result" = "0"; then \
			if grep -q FAIL "$$log"; then result=1; else result=0; fi; \
		fi; \
		if test -f "$$c"; then \
			if diff -b -u "$$log" "$$c" >> "$$log.tmp"; then true; else result=1; fi; \
		fi; \
		if test "$$result" = "0"; then echo "OK"; rm -f "$$log"; else echo "FAIL"; ok=1; fi; \
		rm -f "$$log.tmp"; \
	done; \
	for f in tests/*.out; do test -f "$$f" && cat "$$f"; done; \
	exit "$$ok"

adjac.f95: adjac.f95.in generate.py
	python generate.py adjac.f95.in adjac.f95

adjac_pure.f95: adjac.f95.in generate.py
	python generate.py -DUSE_ALLOCATABLE=True adjac.f95.in adjac_pure.f95

sparse_sum.c: sparse_sum.c.in generate.py
	python generate.py sparse_sum.c.in sparse_sum.c

%.o: %.f95
	$(FC) $(FFLAGS) -c -o $@ $^

%.o: %.c
	gcc -std=c99 $(FFLAGS) -c -o $@ $^

libadjac.a: adjac.o sparse_sum.o
	ar cru $@ $^

libadjac_pure.a: adjac_pure.o sparse_sum.o
	ar cru $@ $^

tests/%.test: tests/%.f95 libadjac.a
	$(FC) $(FFLAGS) -o $@ -Itests $^ -L. -ladjac

tests/%.test_pure: tests/%.f95 libadjac_pure.a
	$(FC) $(FFLAGS) -o $@ -Itests $^ -L. -ladjac_pure

examples/%: examples/%.f95 libadjac.a
	$(FC) $(FFLAGS) -o $@ $^ -L. -ladjac

examples/%_adolc: examples/%_adolc.cpp
	$(CXX) $(CXXFLAGS) $(ADOLC_CFLAGS) -o $@ $^ $(ADOLC_LIBS)

examples/bench_simple_tapeless_adolc: examples/bench_simple_tapeless_adolc.cpp examples/bench_simple_adolc.cpp
	if pkg-config --atleast-version=2.5 adolc; then \
	    exec $(CXX) $(CXXFLAGS) $(ADOLC_CFLAGS) -o $@ $< $(ADOLC_LIBS); \
	else \
	    exec $(CXX) $(CXXFLAGS) $(ADOLC_CFLAGS) -DOLD_TAPELESS -o $@ $< $(ADOLC_LIBS); \
	fi

examples/%_adept: examples/%_adept.cpp
	$(CXX) $(CXXFLAGS) $(ADEPT_CFLAGS) -o $@ $^ $(ADEPT_LIBS)

examples/%_cppad: examples/%_cppad.cpp
	$(CXX) $(CXXFLAGS) $(CPPAD_CFLAGS) -o $@ $^ $(CPPAD_LIBS)

compare_adolc: examples/bench_simple examples/bench_simple_adolc examples/bench_simple_tapeless_adolc
	@echo "-- bench_simple ----------------------------------------"
	@echo "* ADOLC (tape+eval)"
	time ./examples/bench_simple_adolc
	@echo "* ADOLC (tapeless)"
	time ./examples/bench_simple_tapeless_adolc
	@echo "* ADJAC"
	time ./examples/bench_simple

compare_adept: examples/bench_simple examples/bench_simple_adept examples/bench_advection examples/bench_advection_adept
	@echo "-- bench_simple ----------------------------------------"
	@echo "* ADEPT"
	time ./examples/bench_simple_adept
	@echo "* ADJAC"
	time ./examples/bench_simple
	@echo "-- bench_advection ----------------------------------------"
	@echo "* ADEPT"
	time ./examples/bench_advection_adept
	@echo "* ADJAC"
	time ./examples/bench_advection

compare_cppad: examples/bench_simple examples/bench_simple_cppad
	@echo "-- bench_simple ----------------------------------------"
	@echo "* ADEPT"
	time ./examples/bench_simple_cppad
	@echo "* ADJAC"
	time ./examples/bench_simple

compare_numdiff: examples/bench_simple examples/bench_simple_numdiff
	@echo "-- bench_simple ----------------------------------------"
	@echo "* Numerical differentiation"
	time ./examples/bench_simple_numdiff
	@echo "* ADJAC"
	time ./examples/bench_simple


clean:
	rm -f $(EXAMPLES) $(TESTS) tests/*.out *.o adjac.f95 *.mod $(CXXEXAMPLES)

.PHONY: all test examples compare_adolc compare_adept
