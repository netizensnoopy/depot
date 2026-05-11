
SHELL = /bin/sh

# V=0 quiet, V=1 verbose.  other values don't work.
V = 1
V0 = $(V:0=)
Q1 = $(V:1=)
Q = $(Q1:0=@)
ECHO1 = $(V:1=@ :)
ECHO = $(ECHO1:0=@ echo)
NULLCMD = :

#### Start of system configuration section. ####

srcdir = .
topdir = /usr/include/ruby-3.3.0
hdrdir = $(topdir)
arch_hdrdir = /usr/include/ruby-3.3.0/x86_64-linux
PATH_SEPARATOR = :
VPATH = $(srcdir):$(arch_hdrdir)/ruby:$(hdrdir)/ruby
prefix = $(DESTDIR)/usr
rubysitearchprefix = $(rubylibprefix)/$(sitearch)
rubyarchprefix = $(rubylibprefix)/$(arch)
rubylibprefix = $(libdir)/$(RUBY_BASE_NAME)
exec_prefix = $(prefix)
vendorarchhdrdir = $(vendorhdrdir)/$(sitearch)
sitearchhdrdir = $(sitehdrdir)/$(sitearch)
rubyarchhdrdir = $(rubyhdrdir)/$(arch)
vendorhdrdir = $(rubyhdrdir)/vendor_ruby
sitehdrdir = $(rubyhdrdir)/site_ruby
rubyhdrdir = $(includedir)/$(RUBY_VERSION_NAME)
vendorarchdir = $(vendorlibdir)/$(sitearch)
vendorlibdir = $(vendordir)/$(ruby_version)
vendordir = $(rubylibprefix)/vendor_ruby
sitearchdir = $(sitelibdir)/$(sitearch)
sitelibdir = $(sitedir)/$(ruby_version)
sitedir = $(rubylibprefix)/site_ruby
rubyarchdir = $(rubylibdir)/$(arch)
rubylibdir = $(rubylibprefix)/$(ruby_version)
sitearchincludedir = $(includedir)/$(sitearch)
archincludedir = $(includedir)/$(arch)
sitearchlibdir = $(libdir)/$(sitearch)
archlibdir = $(libdir)/$(arch)
ridir = $(datarootdir)/$(RI_BASE_NAME)
mandir = $(DESTDIR)/usr/share/man
localedir = $(datarootdir)/locale
libdir = $(exec_prefix)/lib64
psdir = $(docdir)
pdfdir = $(docdir)
dvidir = $(docdir)
htmldir = $(DESTDIR)/usr/share/doc/ruby-3.3.10-r1/html
infodir = $(DESTDIR)/usr/share/info
docdir = $(DESTDIR)/usr/share/doc/ruby-3.3.10-r1
oldincludedir = $(DESTDIR)/usr/include
includedir = $(prefix)/include
runstatedir = $(localstatedir)/run
localstatedir = $(DESTDIR)/var/lib
sharedstatedir = $(prefix)/com
sysconfdir = $(DESTDIR)/etc
datadir = $(DESTDIR)/usr/share
datarootdir = $(DESTDIR)/usr/share
libexecdir = $(exec_prefix)/libexec
sbindir = $(exec_prefix)/sbin
bindir = $(exec_prefix)/bin
archdir = $(rubyarchdir)


CC_WRAPPER = 
CC = x86_64-pc-linux-gnu-gcc
CXX = x86_64-pc-linux-gnu-g++
LIBRUBY = $(LIBRUBY_SO)
LIBRUBY_A = lib$(RUBY_SO_NAME)-static.a
LIBRUBYARG_SHARED = -l$(RUBY_SO_NAME)
LIBRUBYARG_STATIC = -l$(RUBY_SO_NAME)-static $(MAINLIBS)
empty =
OUTFLAG = -o $(empty)
COUTFLAG = -o $(empty)
CSRCFLAG = $(empty)

RUBY_EXTCONF_H = 
cflags   = $(optflags) $(debugflags) $(warnflags)
cxxflags = 
optflags = -O3 -fno-fast-math
debugflags = -ggdb3
warnflags = -Wall -Wextra -Wdeprecated-declarations -Wdiv-by-zero -Wduplicated-cond -Wimplicit-function-declaration -Wimplicit-int -Wpointer-arith -Wwrite-strings -Wold-style-definition -Wimplicit-fallthrough=0 -Wmissing-noreturn -Wno-cast-function-type -Wno-constant-logical-operand -Wno-long-long -Wno-missing-field-initializers -Wno-overlength-strings -Wno-packed-bitfield-compat -Wno-parentheses-equality -Wno-self-assign -Wno-tautological-compare -Wno-unused-parameter -Wno-unused-value -Wsuggest-attribute=format -Wsuggest-attribute=noreturn -Wunused-variable -Wmisleading-indentation -Wundef
cppflags = 
CCDLFLAGS = -fPIC
CFLAGS   = $(CCDLFLAGS) -O2 -pipe -march=x86-64 -mtune=generic -g -Werror=odr -Werror=lto-type-mismatch -Werror=strict-aliasing -fno-omit-frame-pointer -fno-strict-aliasing -fno-ipa-modref -fPIC $(ARCH_FLAG)
INCFLAGS = -I. -I$(arch_hdrdir) -I$(hdrdir)/ruby/backward -I$(hdrdir) -I$(srcdir) -I/home/user/Documents/depot/ruby-qt6-main/rice/include
DEFS     = 
CPPFLAGS =   $(DEFS) $(cppflags)
CXXFLAGS = $(CCDLFLAGS) -O2 -pipe -march=x86-64 -mtune=generic -g -Werror=odr -Werror=lto-type-mismatch -Werror=strict-aliasing -fno-omit-frame-pointer -fno-strict-aliasing -fno-ipa-modref -std=c++17 $(ARCH_FLAG)
ldflags  = -L. -Wl,-O1 -Wl,--as-needed -Wl,-z,pack-relative-relocs -g -Werror=odr -Werror=lto-type-mismatch -Werror=strict-aliasing -fstack-protector-strong -rdynamic -Wl,-export-dynamic -Wl,--no-as-needed /home/user/Documents/depot/ruby-qt6-main/rice/lib/qt6/rice/rice.so
dldflags = -Wl,-O1 -Wl,--as-needed -Wl,-z,pack-relative-relocs -g -Werror=odr -Werror=lto-type-mismatch -Werror=strict-aliasing 
ARCH_FLAG = 
DLDFLAGS = $(ldflags) $(dldflags) $(ARCH_FLAG)
LDSHARED = $(CC) -shared
LDSHAREDXX = $(CXX) -shared
AR = x86_64-pc-linux-gnu-gcc-ar
EXEEXT = 

RUBY_INSTALL_NAME = $(RUBY_BASE_NAME)33
RUBY_SO_NAME = ruby33
RUBYW_INSTALL_NAME = 
RUBY_VERSION_NAME = $(RUBY_BASE_NAME)-$(ruby_version)
RUBYW_BASE_NAME = rubyw
RUBY_BASE_NAME = ruby

arch = x86_64-linux
sitearch = $(arch)
ruby_version = 3.3.0
ruby = $(bindir)/$(RUBY_BASE_NAME)33
RUBY = $(ruby)
BUILTRUBY = $(bindir)/$(RUBY_BASE_NAME)33
ruby_headers = $(hdrdir)/ruby.h $(hdrdir)/ruby/backward.h $(hdrdir)/ruby/ruby.h $(hdrdir)/ruby/defines.h $(hdrdir)/ruby/missing.h $(hdrdir)/ruby/intern.h $(hdrdir)/ruby/st.h $(hdrdir)/ruby/subst.h $(arch_hdrdir)/ruby/config.h

RM = rm -f
RM_RF = rm -fr
RMDIRS = rmdir --ignore-fail-on-non-empty -p
MAKEDIRS = mkdir -p
INSTALL = /usr/bin/install -c
INSTALL_PROG = $(INSTALL) -m 0755
INSTALL_DATA = $(INSTALL) -m 644
COPY = cp
TOUCH = exit >

#### End of system configuration section. ####

preload = 
libpath = . $(libdir)
LIBPATH =  -L. -L$(libdir)
DEFFILE = 

CLEANFILES = mkmf.log
DISTCLEANFILES = 
DISTCLEANDIRS = 

extout = 
extout_prefix = 
target_prefix = /qt6/qtcore
LOCAL_LIBS = 
LIBS = $(LIBRUBYARG_SHARED) -lQt6Core -lstdc++fs  -lm -lpthread  -lc
ORIG_SRCS = bando-core-rb.cpp bando-qobject-rb.cpp bando-qsortfilterproxymodel-rb.cpp qabstractitemmodel-rb.cpp qabstractproxymodel-rb.cpp qanystringview-rb.cpp qbasictimer-rb.cpp qbytearray-rb.cpp qchar-rb.cpp qcoreapplication-rb.cpp qcoreevent-rb.cpp qdatetime-rb.cpp qdir-rb.cpp qeventloop-rb.cpp qfile-rb.cpp qfiledevice-rb.cpp qfileinfo-rb.cpp qiodevice-rb.cpp qiodevicebase-rb.cpp qitemselection-rb.cpp qitemselectionmodel-rb.cpp qlibraryinfo-rb.cpp qline-rb.cpp qlocale-rb.cpp qmargins-rb.cpp qmetaclassinfo-rb.cpp qmetamethod-rb.cpp qmetaobject-rb.cpp qmetaobjectbuilder-rb.cpp qmetatype-rb.cpp qmimetype-rb.cpp qmodelindex-rb.cpp qobject-rb.cpp qpersistentmodelindex-rb.cpp qpoint-rb.cpp qprocess-rb.cpp qprocessenvironment-rb.cpp qrect-rb.cpp qregularexpression-rb.cpp qresource-rb.cpp qsettings-rb.cpp qsignalmapper-rb.cpp qsize-rb.cpp qsortfilterproxymodel-rb.cpp qstandardpaths-rb.cpp qstring-rb.cpp qstringlist-rb.cpp qt-enum-af-rb.cpp qt-enum-gl-rb.cpp qt-enum-mr-rb.cpp qt-enum-sz-rb.cpp qt-flags-al-rb.cpp qt-flags-mz-rb.cpp qtcore-rb.cpp qtcoreversion-rb.cpp qtextstream-rb.cpp qtimer-rb.cpp qtranslator-rb.cpp qurl-rb.cpp qurlquery-rb.cpp quuid-rb.cpp qvariant-rb.cpp qvariantlist-rb.cpp qvariantmap-rb.cpp t-qtcore-rb.cpp
SRCS = $(ORIG_SRCS) 
OBJS = bando-core-rb.o bando-qobject-rb.o bando-qsortfilterproxymodel-rb.o qabstractitemmodel-rb.o qabstractproxymodel-rb.o qanystringview-rb.o qbasictimer-rb.o qbytearray-rb.o qchar-rb.o qcoreapplication-rb.o qcoreevent-rb.o qdatetime-rb.o qdir-rb.o qeventloop-rb.o qfile-rb.o qfiledevice-rb.o qfileinfo-rb.o qiodevice-rb.o qiodevicebase-rb.o qitemselection-rb.o qitemselectionmodel-rb.o qlibraryinfo-rb.o qline-rb.o qlocale-rb.o qmargins-rb.o qmetaclassinfo-rb.o qmetamethod-rb.o qmetaobject-rb.o qmetaobjectbuilder-rb.o qmetatype-rb.o qmimetype-rb.o qmodelindex-rb.o qobject-rb.o qpersistentmodelindex-rb.o qpoint-rb.o qprocess-rb.o qprocessenvironment-rb.o qrect-rb.o qregularexpression-rb.o qresource-rb.o qsettings-rb.o qsignalmapper-rb.o qsize-rb.o qsortfilterproxymodel-rb.o qstandardpaths-rb.o qstring-rb.o qstringlist-rb.o qt-enum-af-rb.o qt-enum-gl-rb.o qt-enum-mr-rb.o qt-enum-sz-rb.o qt-flags-al-rb.o qt-flags-mz-rb.o qtcore-rb.o qtcoreversion-rb.o qtextstream-rb.o qtimer-rb.o qtranslator-rb.o qurl-rb.o qurlquery-rb.o quuid-rb.o qvariant-rb.o qvariantlist-rb.o qvariantmap-rb.o t-qtcore-rb.o
HDRS = $(srcdir)/bando-core-rb.hpp $(srcdir)/bando-qobject-rb.hpp $(srcdir)/bando-qsortfilterproxymodel-rb.hpp $(srcdir)/qabstractitemmodel-rb.hpp $(srcdir)/qabstractproxymodel-rb.hpp $(srcdir)/qanystringview-rb.hpp $(srcdir)/qbasictimer-rb.hpp $(srcdir)/qbytearray-rb.hpp $(srcdir)/qchar-rb.hpp $(srcdir)/qcoreapplication-rb.hpp $(srcdir)/qcoreevent-rb.hpp $(srcdir)/qdatetime-rb.hpp $(srcdir)/qdir-rb.hpp $(srcdir)/qeventloop-rb.hpp $(srcdir)/qfile-rb.hpp $(srcdir)/qfiledevice-rb.hpp $(srcdir)/qfileinfo-rb.hpp $(srcdir)/qiodevice-rb.hpp $(srcdir)/qiodevicebase-rb.hpp $(srcdir)/qitemselection-rb.hpp $(srcdir)/qitemselectionmodel-rb.hpp $(srcdir)/qlibraryinfo-rb.hpp $(srcdir)/qline-rb.hpp $(srcdir)/qlocale-rb.hpp $(srcdir)/qmargins-rb.hpp $(srcdir)/qmetaclassinfo-rb.hpp $(srcdir)/qmetamethod-rb.hpp $(srcdir)/qmetaobject-rb.hpp $(srcdir)/qmetaobjectbuilder-rb.hpp $(srcdir)/qmetatype-rb.hpp $(srcdir)/qmimetype-rb.hpp $(srcdir)/qmodelindex-rb.hpp $(srcdir)/qobject-rb.hpp $(srcdir)/qpersistentmodelindex-rb.hpp $(srcdir)/qpoint-rb.hpp $(srcdir)/qprocess-rb.hpp $(srcdir)/qprocessenvironment-rb.hpp $(srcdir)/qrect-rb.hpp $(srcdir)/qregularexpression-rb.hpp $(srcdir)/qresource-rb.hpp $(srcdir)/qsettings-rb.hpp $(srcdir)/qsignalmapper-rb.hpp $(srcdir)/qsize-rb.hpp $(srcdir)/qsortfilterproxymodel-rb.hpp $(srcdir)/qstandardpaths-rb.hpp $(srcdir)/qstring-rb.hpp $(srcdir)/qstringlist-rb.hpp $(srcdir)/qt-enum-af-rb.hpp $(srcdir)/qt-enum-gl-rb.hpp $(srcdir)/qt-enum-mr-rb.hpp $(srcdir)/qt-enum-sz-rb.hpp $(srcdir)/qt-flags-al-rb.hpp $(srcdir)/qt-flags-mz-rb.hpp $(srcdir)/qtcore-rb.hpp $(srcdir)/qtcoreversion-rb.hpp $(srcdir)/qtextstream-rb.hpp $(srcdir)/qtimer-rb.hpp $(srcdir)/qtranslator-rb.hpp $(srcdir)/qurl-rb.hpp $(srcdir)/qurlquery-rb.hpp $(srcdir)/quuid-rb.hpp $(srcdir)/qvariant-rb.hpp $(srcdir)/qvariantlist-rb.hpp $(srcdir)/qvariantmap-rb.hpp $(srcdir)/t-qtcore-rb.hpp
LOCAL_HDRS = 
TARGET = qtcore
TARGET_NAME = qtcore
TARGET_ENTRY = Init_$(TARGET_NAME)
DLLIB = $(TARGET).so
EXTSTATIC = 
STATIC_LIB = 

TIMESTAMP_DIR = .
BINDIR        = $(bindir)
RUBYCOMMONDIR = $(sitedir)$(target_prefix)
RUBYLIBDIR    = $(sitelibdir)$(target_prefix)
RUBYARCHDIR   = $(sitearchdir)$(target_prefix)
HDRDIR        = $(sitehdrdir)$(target_prefix)
ARCHHDRDIR    = $(sitearchhdrdir)$(target_prefix)
TARGET_SO_DIR =
TARGET_SO     = $(TARGET_SO_DIR)$(DLLIB)
CLEANLIBS     = $(TARGET_SO) false
CLEANOBJS     = $(OBJS) *.bak
TARGET_SO_DIR_TIMESTAMP = $(TIMESTAMP_DIR)/.sitearchdir.-.qt6.-.qtcore.time

all:    $(DLLIB)
static: $(STATIC_LIB)
.PHONY: all install static install-so install-rb
.PHONY: clean clean-so clean-static clean-rb

clean-static::
clean-rb-default::
clean-rb::
clean-so::
clean: clean-so clean-static clean-rb-default clean-rb
		-$(Q)$(RM_RF) $(CLEANLIBS) $(CLEANOBJS) $(CLEANFILES) .*.time

distclean-rb-default::
distclean-rb::
distclean-so::
distclean-static::
distclean: clean distclean-so distclean-static distclean-rb-default distclean-rb
		-$(Q)$(RM) Makefile $(RUBY_EXTCONF_H) conftest.* mkmf.log
		-$(Q)$(RM) core ruby$(EXEEXT) *~ $(DISTCLEANFILES)
		-$(Q)$(RMDIRS) $(DISTCLEANDIRS) 2> /dev/null || true

realclean: distclean
install: install-so install-rb

install-so: $(DLLIB) $(TARGET_SO_DIR_TIMESTAMP)
	$(INSTALL_PROG) $(DLLIB) $(RUBYARCHDIR)
clean-static::
	-$(Q)$(RM) $(STATIC_LIB)
install-rb: pre-install-rb do-install-rb install-rb-default
install-rb-default: pre-install-rb-default do-install-rb-default
pre-install-rb: Makefile
pre-install-rb-default: Makefile
do-install-rb:
do-install-rb-default:
pre-install-rb-default:
	@$(NULLCMD)
$(TARGET_SO_DIR_TIMESTAMP):
	$(Q) $(MAKEDIRS) $(@D) $(RUBYARCHDIR)
	$(Q) $(TOUCH) $@

site-install: site-install-so site-install-rb
site-install-so: install-so
site-install-rb: install-rb

.SUFFIXES: .c .m .cc .mm .cxx .cpp .o .S

.cc.o:
	$(ECHO) compiling $(<)
	$(Q) $(CXX) $(INCFLAGS) $(CPPFLAGS) $(CXXFLAGS) $(COUTFLAG)$@ -c $(CSRCFLAG)$<

.cc.S:
	$(ECHO) translating $(<)
	$(Q) $(CXX) $(INCFLAGS) $(CPPFLAGS) $(CXXFLAGS) $(COUTFLAG)$@ -S $(CSRCFLAG)$<

.mm.o:
	$(ECHO) compiling $(<)
	$(Q) $(CXX) $(INCFLAGS) $(CPPFLAGS) $(CXXFLAGS) $(COUTFLAG)$@ -c $(CSRCFLAG)$<

.mm.S:
	$(ECHO) translating $(<)
	$(Q) $(CXX) $(INCFLAGS) $(CPPFLAGS) $(CXXFLAGS) $(COUTFLAG)$@ -S $(CSRCFLAG)$<

.cxx.o:
	$(ECHO) compiling $(<)
	$(Q) $(CXX) $(INCFLAGS) $(CPPFLAGS) $(CXXFLAGS) $(COUTFLAG)$@ -c $(CSRCFLAG)$<

.cxx.S:
	$(ECHO) translating $(<)
	$(Q) $(CXX) $(INCFLAGS) $(CPPFLAGS) $(CXXFLAGS) $(COUTFLAG)$@ -S $(CSRCFLAG)$<

.cpp.o:
	$(ECHO) compiling $(<)
	$(Q) $(CXX) $(INCFLAGS) $(CPPFLAGS) $(CXXFLAGS) $(COUTFLAG)$@ -c $(CSRCFLAG)$<

.cpp.S:
	$(ECHO) translating $(<)
	$(Q) $(CXX) $(INCFLAGS) $(CPPFLAGS) $(CXXFLAGS) $(COUTFLAG)$@ -S $(CSRCFLAG)$<

.c.o:
	$(ECHO) compiling $(<)
	$(Q) $(CC) $(INCFLAGS) $(CPPFLAGS) $(CFLAGS) $(COUTFLAG)$@ -c $(CSRCFLAG)$<

.c.S:
	$(ECHO) translating $(<)
	$(Q) $(CC) $(INCFLAGS) $(CPPFLAGS) $(CFLAGS) $(COUTFLAG)$@ -S $(CSRCFLAG)$<

.m.o:
	$(ECHO) compiling $(<)
	$(Q) $(CC) $(INCFLAGS) $(CPPFLAGS) $(CFLAGS) $(COUTFLAG)$@ -c $(CSRCFLAG)$<

.m.S:
	$(ECHO) translating $(<)
	$(Q) $(CC) $(INCFLAGS) $(CPPFLAGS) $(CFLAGS) $(COUTFLAG)$@ -S $(CSRCFLAG)$<

$(TARGET_SO): $(OBJS) Makefile
	$(ECHO) linking shared-object qt6/qtcore/$(DLLIB)
	-$(Q)$(RM) $(@)
	$(Q) $(LDSHAREDXX) -o $@ $(OBJS) $(LIBPATH) $(DLDFLAGS) $(LOCAL_LIBS) $(LIBS)



$(OBJS): $(HDRS) $(ruby_headers)
