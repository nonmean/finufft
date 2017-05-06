# Makefile for Flatiron Institute (FI) NUFFT libraries.
# Barnett 4/5/17

# This is the only makefile; there are no makefiles in subdirectories.
# If you need to edit this makefile, it is recommended that you first
# copy it to makefile.local, edit that, and use make -f makefile.local

# Compilation options:
#
# 1) Use "make [task] PREC=SINGLE" for single-precision, otherwise will be
#    double-precision. Single-precision saves half the RAM, and increases
#    speed slightly (<20%). Will break matlab, octave, python interfaces.
# 2) make with OMP=OFF for single-threaded, otherwise multi-threaded (openmp).
# 3) If you want to restrict to array sizes <2^31 and explore if 32-bit integer
#    indexing beats 64-bit, add flag -DSMALLINT to CXXFLAGS which sets BIGINT
#    to int.
# 4) If you want 32 bit integers in the FINUFFT library interface instead of
#    int64, add flag -DINTERFACE32 (experimental, C,F,M,O interfaces will break)

# compilers...
CXX=g++
CC=gcc
FC=gfortran
# for non-C++ compilers to be able to link to library...
CLINK=-lstdc++
FLINK=-lstdc++

# basic compile flags for single-threaded, double precision...
CXXFLAGS = -fPIC -Ofast -funroll-loops -std=c++11 -DNEED_EXTERN_C
CFLAGS = -fPIC -Ofast -funroll-loops
FFLAGS = -fPIC -O3 -funroll-loops
# Here MFLAGS are for MATLAB, OFLAGS for octave:
MFLAGS = -largeArrayDims -lrt
# Mac users instead should use something like this:
#MFLAGS = -largeArrayDims -L/usr/local/gfortran/lib -lgfortran -lm
OFLAGS = -lrt
# for mkoctfile version >= 4.0.0 you can remove warnings by using:
#OFLAGS += -std=c++11
# location of MATLAB's mex compiler...
MEX=mex
# Mac users should use something like this:
#MEX = /Applications/MATLAB_R2017a.app/bin/mex
# location of your MWrap executable (see INSTALL.md):
MWRAP=mwrap

# choose the precision (sets fftw library names, test precisions)...
ifeq ($(PREC),SINGLE)
CXXFLAGS += -DSINGLE
CFLAGS += -DSINGLE
SUFFIX = f
REQ_TOL = 1e-6
CHECK_TOL = 2e-4
else
SUFFIX = 
REQ_TOL = 1e-12
CHECK_TOL = 1e-11
endif
FFTW = fftw3$(SUFFIX)
LIBSFFT = -l$(FFTW) -lm

# multi-threaded libs & flags needed...
ifneq ($(OMP),OFF)
CXXFLAGS += -fopenmp
CFLAGS += -fopenmp
FFLAGS += -fopenmp
MFLAGS += -lgomp -D_OPENMP
OFLAGS += -lgomp
LIBSFFT += -l$(FFTW)_threads
endif

# ======================================================================

# objects to compile: spreader...
SOBJS = src/cnufftspread.o src/cnufftspread_advanced.o src/utils.o
# for NUFFT library and its testers...
OBJS = $(SOBJS) src/finufft1d.o src/finufft2d.o src/finufft3d.o src/dirft1d.o src/dirft2d.o src/dirft3d.o src/common.o contrib/legendre_rule_fast.o src/finufft_c.o fortran/finufft_f.o
OBJS1 = $(SOBJS) src/finufft1d.o src/dirft1d.o src/common.o contrib/legendre_rule_fast.o
OBJS2 = $(SOBJS) src/finufft2d.o src/dirft2d.o src/common.o contrib/legendre_rule_fast.o
OBJS3 = $(SOBJS) src/finufft3d.o src/dirft3d.o src/common.o contrib/legendre_rule_fast.o
# for Fortran interface demos...
FOBJS = fortran/dirft1d.o fortran/dirft2d.o fortran/dirft3d.o fortran/dirft1df.o fortran/dirft2df.o fortran/dirft3df.o fortran/prini.o

HEADERS = src/cnufftspread.h src/cnufftspread_advanced.h src/finufft.h src/dirft.h src/common.h src/utils.h src/finufft_c.h fortran/finufft_f.h

.PHONY: usage lib examples test perftest fortran matlab octave python all mex

default: usage

all: test perftest lib examples fortran matlab octave python

usage:
	@echo "Makefile for FINUFFT library. Specify what to make:"
	@echo " make lib - compile the main libraries (in lib/)"
	@echo " make examples - compile and run codes in examples/"
	@echo " make test - compile and run math validation tests"
	@echo " make perftest - compile and run performance tests"
	@echo " make fortran - compile and test Fortran interfaces"
	@echo " make matlab - compile Matlab interfaces"
	@echo " make octave - compile and test octave interfaces"
	@echo " make python - compile and test python interfaces"
	@echo " make all - do all of the above"
	@echo " make clean - remove all object and executable files apart from MEX"
	@echo "For faster (multicore) making you may want to append the flag -j"
	@echo ""
	@echo "Compile options: make [task] PREC=SINGLE for single-precision"
	@echo " make [task] OMP=OFF for single-threaded (otherwise openmp)"

# implicit rules for objects (note -o ensures writes to correct dir)
%.o: %.cpp %.h
	$(CXX) -c $(CXXFLAGS) $< -o $@
%.o: %.c %.h
	$(CC) -c $(CFLAGS) $< -o $@
%.o: %.f %.h
	$(FC) -c $(FFLAGS) $< -o $@

# build the library...
lib: lib/libfinufft.a lib/libfinufft.so
	echo "lib/libfinufft.a and lib/libfinufft.so built"
lib/libfinufft.a: $(OBJS) $(HEADERS)
	ar rcs lib/libfinufft.a $(OBJS)
lib/libfinufft.so: $(OBJS) $(HEADERS)
	$(CXX) -shared $(OBJS) -o lib/libfinufft.so      # fails in mac osx
# see: http://www.cprogramming.com/tutorial/shared-libraries-linux-gcc.html

# examples in C++ and C...                *** TO FIX C CAN"T FIND C++ HEADERS
EX = examples/example1d1$(SUFFIX)
EXC = examples/example1d1c$(SUFFIX)
examples: $(EX) $(EXC)
	$(EX)
	$(EXC)
$(EX): $(EX).o lib/libfinufft.a
	$(CXX) $(CXXFLAGS) $(EX).o lib/libfinufft.a $(LIBSFFT) -o $(EX)
$(EXC): $(EXC).o lib/libfinufft.a
	$(CC) $(CFLAGS) $(EXC).o lib/libfinufft.a $(LIBSFFT) $(CLINK) -o $(EXC)

# validation tests... (most link to .o allowing testing pieces separately)
test: lib/libfinufft.a test/testutils test/finufft1d_test test/finufft2d_test test/finufft3d_test test/dumbinputs
	(cd test; \
	export FINUFFT_REQ_TOL=$(REQ_TOL); \
	export FINUFFT_CHECK_TOL=$(CHECK_TOL); \
	./check_finufft.sh)
test/testutils: test/testutils.cpp src/utils.o src/utils.h $(HEADERS)
	$(CXX) $(CXXFLAGS) test/testutils.cpp src/utils.o -o test/testutils
test/finufft1d_test: test/finufft1d_test.cpp $(OBJS1) $(HEADERS)
	$(CXX) $(CXXFLAGS) test/finufft1d_test.cpp $(OBJS1) $(LIBSFFT) -o test/finufft1d_test
test/finufft2d_test: test/finufft2d_test.cpp $(OBJS2) $(HEADERS)
	$(CXX) $(CXXFLAGS) test/finufft2d_test.cpp $(OBJS2) $(LIBSFFT) -o test/finufft2d_test
test/finufft3d_test: test/finufft3d_test.cpp $(OBJS3) $(HEADERS)
	$(CXX) $(CXXFLAGS) test/finufft3d_test.cpp $(OBJS3) $(LIBSFFT) -o test/finufft3d_test
test/dumbinputs: test/dumbinputs.cpp lib/libfinufft.a $(HEADERS)
	$(CXX) $(CXXFLAGS) test/dumbinputs.cpp lib/libfinufft.a $(LIBSFFT) -o test/dumbinputs

# performance tests...
perftest: test/spreadtestnd test/finufft1d_test test/finufft2d_test test/finufft3d_test
# here the tee cmd copies output to screen. 2>&1 grabs both stdout and stderr...
	(cd test; ./spreadtestnd.sh 2>&1 | tee results/spreadtestnd_results.txt)
	(cd test; ./nuffttestnd.sh 2>&1 | tee results/nuffttestnd_results.txt)
test/spreadtestnd: test/spreadtestnd.cpp $(SOBJS) $(HEADERS)
	$(CXX) $(CXXFLAGS) test/spreadtestnd.cpp $(SOBJS) -o test/spreadtestnd

# fortran interface...
F1=fortran/nufft1d_demo$(SUFFIX)
F2=fortran/nufft2d_demo$(SUFFIX)
F3=fortran/nufft3d_demo$(SUFFIX)
fortran: $(FOBJS) $(OBJS) $(HEADERS)
	$(FC) $(FFLAGS) $(F1).f $(FOBJS) $(OBJS) $(LIBSFFT) $(FLINK) -o $(F1)
	$(FC) $(FFLAGS) $(F2).f $(FOBJS) $(OBJS) $(LIBSFFT) $(FLINK) -o $(F2)
	$(FC) $(FFLAGS) $(F3).f $(FOBJS) $(OBJS) $(LIBSFFT) $(FLINK) -o $(F3)
	time -p $(F1)
	time -p $(F2)
	time -p $(F3)

# matlab .mex* executable...
matlab: lib/libfinufft.a $(HEADERS) matlab/finufft_m.o
	$(MEX) matlab/finufft.cpp lib/libfinufft.a matlab/finufft_m.o $(MFLAGS) $(LIBSFFT) -output matlab/finufft

# octave .mex executable...
octave: lib/libfinufft.a $(HEADERS) matlab/finufft_m.o
	mkoctfile --mex matlab/finufft.cpp lib/libfinufft.a matlab/finufft_m.o $(OFLAGS) $(LIBSFFT) -output matlab/finufft
	@echo "Running octave interface test; please wait a few seconds..."
	(cd matlab; octave check_finufft.m)

# for experts: force rebuilds fresh MEX (matlab/octave) gateway via mwrap...
# (needs mwrap)
mex: matlab/finufft.mw
	(cd matlab;\
	$(MWRAP) -list -mex finufft -cppcomplex -mb finufft.mw ;\
	$(MWRAP) -mex finufft -c finufft.cpp -cppcomplex finufft.mw )

# python wrapper... (awaiting completion)
python: python/setup.py python/demo.py python/finufft/build.py python/finufft/__init__.py python/finufft/interface.cpp
	(cd python; rm -rf build ;\
	python setup.py build_ext --inplace ;\
	python demo.py )

# various obscure devel tests...
devel/plotkernels: $(SOBJS) $(HEADERS) devel/plotkernels.cpp
	$(CXX) $(CXXFLAGS) devel/plotkernels.cpp -o devel/plotkernels $(SOBJS) 
	(cd devel; ./plotkernels > plotkernels.dat)

devel/testi0: devel/testi0.cpp devel/besseli.o src/utils.o
	$(CXX) $(CXXFLAGS) devel/testi0.cpp $(OBJS) -o devel/testi0
	(cd devel; ./testi0)

# cleaning up...
clean:
	rm -f $(OBJS) $(SOBJS)
	rm -f test/spreadtestnd test/finufft?d_test test/testutils test/results/*.out fortran/*.o fortran/nufft?d_demo fortran/nufft?d_demof examples/*.o examples/example1d1 examples/example1d1cexamples/example1d1f examples/example1d1cf matlab/*.o

# only do this if you have mwrap to rebuild the interfaces...
mexclean:
	rm -f matlab/finufft.cpp matlab/finufft?d?.m matlab/finufft.mex*
