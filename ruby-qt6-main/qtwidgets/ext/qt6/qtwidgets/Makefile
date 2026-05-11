
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
target_prefix = /qt6/qtwidgets
LOCAL_LIBS = 
LIBS = $(LIBRUBYARG_SHARED) -lQt6Widgets -lQt6Gui -lQt6Core -lstdc++fs  -lm -lpthread  -lc
ORIG_SRCS = bando-qcalendarwidget-rb.cpp bando-qcheckbox-rb.cpp bando-qcolordialog-rb.cpp bando-qcolumnview-rb.cpp bando-qcombobox-rb.cpp bando-qcommandlinkbutton-rb.cpp bando-qdateedit-rb.cpp bando-qdatetimeedit-rb.cpp bando-qdial-rb.cpp bando-qdialog-rb.cpp bando-qdialogbuttonbox-rb.cpp bando-qdockwidget-rb.cpp bando-qdoublespinbox-rb.cpp bando-qerrormessage-rb.cpp bando-qfiledialog-rb.cpp bando-qfocusframe-rb.cpp bando-qfontcombobox-rb.cpp bando-qfontdialog-rb.cpp bando-qframe-rb.cpp bando-qgraphicsview-rb.cpp bando-qgroupbox-rb.cpp bando-qheaderview-rb.cpp bando-qinputdialog-rb.cpp bando-qitemdelegate-rb.cpp bando-qkeysequenceedit-rb.cpp bando-qlabel-rb.cpp bando-qlayout-rb.cpp bando-qlcdnumber-rb.cpp bando-qlineedit-rb.cpp bando-qlistview-rb.cpp bando-qlistwidget-rb.cpp bando-qmainwindow-rb.cpp bando-qmdiarea-rb.cpp bando-qmdisubwindow-rb.cpp bando-qmenu-rb.cpp bando-qmenubar-rb.cpp bando-qmessagebox-rb.cpp bando-qplaintextedit-rb.cpp bando-qprogressbar-rb.cpp bando-qprogressdialog-rb.cpp bando-qpushbutton-rb.cpp bando-qradiobutton-rb.cpp bando-qrubberband-rb.cpp bando-qscrollarea-rb.cpp bando-qscrollbar-rb.cpp bando-qsizegrip-rb.cpp bando-qslider-rb.cpp bando-qspinbox-rb.cpp bando-qsplashscreen-rb.cpp bando-qsplitter-rb.cpp bando-qsplitterhandle-rb.cpp bando-qstackedwidget-rb.cpp bando-qstatusbar-rb.cpp bando-qstyleditemdelegate-rb.cpp bando-qtabbar-rb.cpp bando-qtableview-rb.cpp bando-qtablewidget-rb.cpp bando-qtabwidget-rb.cpp bando-qtextbrowser-rb.cpp bando-qtextedit-rb.cpp bando-qtimeedit-rb.cpp bando-qtoolbar-rb.cpp bando-qtoolbox-rb.cpp bando-qtoolbutton-rb.cpp bando-qtreeview-rb.cpp bando-qtreewidget-rb.cpp bando-qundoview-rb.cpp bando-qwidget-rb.cpp bando-qwizard-rb.cpp bando-qwizardpage-rb.cpp qabstractbutton-rb.cpp qabstractitemdelegate-rb.cpp qabstractitemview-rb.cpp qabstractscrollarea-rb.cpp qabstractslider-rb.cpp qabstractspinbox-rb.cpp qapplication-rb.cpp qboxlayout-rb.cpp qcalendarwidget-rb.cpp qcheckbox-rb.cpp qcolordialog-rb.cpp qcolumnview-rb.cpp qcombobox-rb.cpp qcommandlinkbutton-rb.cpp qdatetimeedit-rb.cpp qdial-rb.cpp qdialog-rb.cpp qdialogbuttonbox-rb.cpp qdockwidget-rb.cpp qerrormessage-rb.cpp qfiledialog-rb.cpp qfileiconprovider-rb.cpp qfocusframe-rb.cpp qfontcombobox-rb.cpp qfontdialog-rb.cpp qformlayout-rb.cpp qframe-rb.cpp qgraphicsitem-rb.cpp qgraphicsobject-rb.cpp qgraphicsscene-rb.cpp qgraphicstextitem-rb.cpp qgraphicsview-rb.cpp qgraphicswidget-rb.cpp qgridlayout-rb.cpp qgroupbox-rb.cpp qheaderview-rb.cpp qinputdialog-rb.cpp qitemdelegate-rb.cpp qkeysequenceedit-rb.cpp qlabel-rb.cpp qlayout-rb.cpp qlayoutitem-rb.cpp qlcdnumber-rb.cpp qlineedit-rb.cpp qlistview-rb.cpp qlistwidget-rb.cpp qmainwindow-rb.cpp qmdiarea-rb.cpp qmdisubwindow-rb.cpp qmenu-rb.cpp qmenubar-rb.cpp qmessagebox-rb.cpp qplaintextedit-rb.cpp qprogressbar-rb.cpp qprogressdialog-rb.cpp qpushbutton-rb.cpp qradiobutton-rb.cpp qrubberband-rb.cpp qscrollarea-rb.cpp qscrollbar-rb.cpp qsizegrip-rb.cpp qsizepolicy-rb.cpp qslider-rb.cpp qspinbox-rb.cpp qsplashscreen-rb.cpp qsplitter-rb.cpp qstackedlayout-rb.cpp qstackedwidget-rb.cpp qstatusbar-rb.cpp qstyle-rb.cpp qstyleditemdelegate-rb.cpp qstylefactory-rb.cpp qstyleoption-rb.cpp qsystemtrayicon-rb.cpp qtabbar-rb.cpp qtableview-rb.cpp qtablewidget-rb.cpp qtabwidget-rb.cpp qtextbrowser-rb.cpp qtextedit-rb.cpp qtoolbar-rb.cpp qtoolbox-rb.cpp qtoolbutton-rb.cpp qtooltip-rb.cpp qtreeview-rb.cpp qtreewidget-rb.cpp qtwidgets-rb.cpp qtwidgetspreludes-rb.cpp qtwidgetsversion-rb.cpp qundoview-rb.cpp qwidget-rb.cpp qwizard-rb.cpp t-qtwidgets-rb.cpp
SRCS = $(ORIG_SRCS) 
OBJS = bando-qcalendarwidget-rb.o bando-qcheckbox-rb.o bando-qcolordialog-rb.o bando-qcolumnview-rb.o bando-qcombobox-rb.o bando-qcommandlinkbutton-rb.o bando-qdateedit-rb.o bando-qdatetimeedit-rb.o bando-qdial-rb.o bando-qdialog-rb.o bando-qdialogbuttonbox-rb.o bando-qdockwidget-rb.o bando-qdoublespinbox-rb.o bando-qerrormessage-rb.o bando-qfiledialog-rb.o bando-qfocusframe-rb.o bando-qfontcombobox-rb.o bando-qfontdialog-rb.o bando-qframe-rb.o bando-qgraphicsview-rb.o bando-qgroupbox-rb.o bando-qheaderview-rb.o bando-qinputdialog-rb.o bando-qitemdelegate-rb.o bando-qkeysequenceedit-rb.o bando-qlabel-rb.o bando-qlayout-rb.o bando-qlcdnumber-rb.o bando-qlineedit-rb.o bando-qlistview-rb.o bando-qlistwidget-rb.o bando-qmainwindow-rb.o bando-qmdiarea-rb.o bando-qmdisubwindow-rb.o bando-qmenu-rb.o bando-qmenubar-rb.o bando-qmessagebox-rb.o bando-qplaintextedit-rb.o bando-qprogressbar-rb.o bando-qprogressdialog-rb.o bando-qpushbutton-rb.o bando-qradiobutton-rb.o bando-qrubberband-rb.o bando-qscrollarea-rb.o bando-qscrollbar-rb.o bando-qsizegrip-rb.o bando-qslider-rb.o bando-qspinbox-rb.o bando-qsplashscreen-rb.o bando-qsplitter-rb.o bando-qsplitterhandle-rb.o bando-qstackedwidget-rb.o bando-qstatusbar-rb.o bando-qstyleditemdelegate-rb.o bando-qtabbar-rb.o bando-qtableview-rb.o bando-qtablewidget-rb.o bando-qtabwidget-rb.o bando-qtextbrowser-rb.o bando-qtextedit-rb.o bando-qtimeedit-rb.o bando-qtoolbar-rb.o bando-qtoolbox-rb.o bando-qtoolbutton-rb.o bando-qtreeview-rb.o bando-qtreewidget-rb.o bando-qundoview-rb.o bando-qwidget-rb.o bando-qwizard-rb.o bando-qwizardpage-rb.o qabstractbutton-rb.o qabstractitemdelegate-rb.o qabstractitemview-rb.o qabstractscrollarea-rb.o qabstractslider-rb.o qabstractspinbox-rb.o qapplication-rb.o qboxlayout-rb.o qcalendarwidget-rb.o qcheckbox-rb.o qcolordialog-rb.o qcolumnview-rb.o qcombobox-rb.o qcommandlinkbutton-rb.o qdatetimeedit-rb.o qdial-rb.o qdialog-rb.o qdialogbuttonbox-rb.o qdockwidget-rb.o qerrormessage-rb.o qfiledialog-rb.o qfileiconprovider-rb.o qfocusframe-rb.o qfontcombobox-rb.o qfontdialog-rb.o qformlayout-rb.o qframe-rb.o qgraphicsitem-rb.o qgraphicsobject-rb.o qgraphicsscene-rb.o qgraphicstextitem-rb.o qgraphicsview-rb.o qgraphicswidget-rb.o qgridlayout-rb.o qgroupbox-rb.o qheaderview-rb.o qinputdialog-rb.o qitemdelegate-rb.o qkeysequenceedit-rb.o qlabel-rb.o qlayout-rb.o qlayoutitem-rb.o qlcdnumber-rb.o qlineedit-rb.o qlistview-rb.o qlistwidget-rb.o qmainwindow-rb.o qmdiarea-rb.o qmdisubwindow-rb.o qmenu-rb.o qmenubar-rb.o qmessagebox-rb.o qplaintextedit-rb.o qprogressbar-rb.o qprogressdialog-rb.o qpushbutton-rb.o qradiobutton-rb.o qrubberband-rb.o qscrollarea-rb.o qscrollbar-rb.o qsizegrip-rb.o qsizepolicy-rb.o qslider-rb.o qspinbox-rb.o qsplashscreen-rb.o qsplitter-rb.o qstackedlayout-rb.o qstackedwidget-rb.o qstatusbar-rb.o qstyle-rb.o qstyleditemdelegate-rb.o qstylefactory-rb.o qstyleoption-rb.o qsystemtrayicon-rb.o qtabbar-rb.o qtableview-rb.o qtablewidget-rb.o qtabwidget-rb.o qtextbrowser-rb.o qtextedit-rb.o qtoolbar-rb.o qtoolbox-rb.o qtoolbutton-rb.o qtooltip-rb.o qtreeview-rb.o qtreewidget-rb.o qtwidgets-rb.o qtwidgetspreludes-rb.o qtwidgetsversion-rb.o qundoview-rb.o qwidget-rb.o qwizard-rb.o t-qtwidgets-rb.o
HDRS = $(srcdir)/bando-qcalendarwidget-rb.hpp $(srcdir)/bando-qcheckbox-rb.hpp $(srcdir)/bando-qcolordialog-rb.hpp $(srcdir)/bando-qcolumnview-rb.hpp $(srcdir)/bando-qcombobox-rb.hpp $(srcdir)/bando-qcommandlinkbutton-rb.hpp $(srcdir)/bando-qdateedit-rb.hpp $(srcdir)/bando-qdatetimeedit-rb.hpp $(srcdir)/bando-qdial-rb.hpp $(srcdir)/bando-qdialog-rb.hpp $(srcdir)/bando-qdialogbuttonbox-rb.hpp $(srcdir)/bando-qdockwidget-rb.hpp $(srcdir)/bando-qdoublespinbox-rb.hpp $(srcdir)/bando-qerrormessage-rb.hpp $(srcdir)/bando-qfiledialog-rb.hpp $(srcdir)/bando-qfocusframe-rb.hpp $(srcdir)/bando-qfontcombobox-rb.hpp $(srcdir)/bando-qfontdialog-rb.hpp $(srcdir)/bando-qframe-rb.hpp $(srcdir)/bando-qgraphicsview-rb.hpp $(srcdir)/bando-qgroupbox-rb.hpp $(srcdir)/bando-qheaderview-rb.hpp $(srcdir)/bando-qinputdialog-rb.hpp $(srcdir)/bando-qitemdelegate-rb.hpp $(srcdir)/bando-qkeysequenceedit-rb.hpp $(srcdir)/bando-qlabel-rb.hpp $(srcdir)/bando-qlayout-rb.hpp $(srcdir)/bando-qlcdnumber-rb.hpp $(srcdir)/bando-qlineedit-rb.hpp $(srcdir)/bando-qlistview-rb.hpp $(srcdir)/bando-qlistwidget-rb.hpp $(srcdir)/bando-qmainwindow-rb.hpp $(srcdir)/bando-qmdiarea-rb.hpp $(srcdir)/bando-qmdisubwindow-rb.hpp $(srcdir)/bando-qmenu-rb.hpp $(srcdir)/bando-qmenubar-rb.hpp $(srcdir)/bando-qmessagebox-rb.hpp $(srcdir)/bando-qplaintextedit-rb.hpp $(srcdir)/bando-qprogressbar-rb.hpp $(srcdir)/bando-qprogressdialog-rb.hpp $(srcdir)/bando-qpushbutton-rb.hpp $(srcdir)/bando-qradiobutton-rb.hpp $(srcdir)/bando-qrubberband-rb.hpp $(srcdir)/bando-qscrollarea-rb.hpp $(srcdir)/bando-qscrollbar-rb.hpp $(srcdir)/bando-qsizegrip-rb.hpp $(srcdir)/bando-qslider-rb.hpp $(srcdir)/bando-qspinbox-rb.hpp $(srcdir)/bando-qsplashscreen-rb.hpp $(srcdir)/bando-qsplitter-rb.hpp $(srcdir)/bando-qsplitterhandle-rb.hpp $(srcdir)/bando-qstackedwidget-rb.hpp $(srcdir)/bando-qstatusbar-rb.hpp $(srcdir)/bando-qstyleditemdelegate-rb.hpp $(srcdir)/bando-qtabbar-rb.hpp $(srcdir)/bando-qtableview-rb.hpp $(srcdir)/bando-qtablewidget-rb.hpp $(srcdir)/bando-qtabwidget-rb.hpp $(srcdir)/bando-qtextbrowser-rb.hpp $(srcdir)/bando-qtextedit-rb.hpp $(srcdir)/bando-qtimeedit-rb.hpp $(srcdir)/bando-qtoolbar-rb.hpp $(srcdir)/bando-qtoolbox-rb.hpp $(srcdir)/bando-qtoolbutton-rb.hpp $(srcdir)/bando-qtreeview-rb.hpp $(srcdir)/bando-qtreewidget-rb.hpp $(srcdir)/bando-qundoview-rb.hpp $(srcdir)/bando-qwidget-rb.hpp $(srcdir)/bando-qwizard-rb.hpp $(srcdir)/bando-qwizardpage-rb.hpp $(srcdir)/qabstractbutton-rb.hpp $(srcdir)/qabstractitemdelegate-rb.hpp $(srcdir)/qabstractitemview-rb.hpp $(srcdir)/qabstractscrollarea-rb.hpp $(srcdir)/qabstractslider-rb.hpp $(srcdir)/qabstractspinbox-rb.hpp $(srcdir)/qapplication-rb.hpp $(srcdir)/qboxlayout-rb.hpp $(srcdir)/qcalendarwidget-rb.hpp $(srcdir)/qcheckbox-rb.hpp $(srcdir)/qcolordialog-rb.hpp $(srcdir)/qcolumnview-rb.hpp $(srcdir)/qcombobox-rb.hpp $(srcdir)/qcommandlinkbutton-rb.hpp $(srcdir)/qdatetimeedit-rb.hpp $(srcdir)/qdial-rb.hpp $(srcdir)/qdialog-rb.hpp $(srcdir)/qdialogbuttonbox-rb.hpp $(srcdir)/qdockwidget-rb.hpp $(srcdir)/qerrormessage-rb.hpp $(srcdir)/qfiledialog-rb.hpp $(srcdir)/qfileiconprovider-rb.hpp $(srcdir)/qfocusframe-rb.hpp $(srcdir)/qfontcombobox-rb.hpp $(srcdir)/qfontdialog-rb.hpp $(srcdir)/qformlayout-rb.hpp $(srcdir)/qframe-rb.hpp $(srcdir)/qgraphicsitem-rb.hpp $(srcdir)/qgraphicsobject-rb.hpp $(srcdir)/qgraphicsscene-rb.hpp $(srcdir)/qgraphicstextitem-rb.hpp $(srcdir)/qgraphicsview-rb.hpp $(srcdir)/qgraphicswidget-rb.hpp $(srcdir)/qgridlayout-rb.hpp $(srcdir)/qgroupbox-rb.hpp $(srcdir)/qheaderview-rb.hpp $(srcdir)/qinputdialog-rb.hpp $(srcdir)/qitemdelegate-rb.hpp $(srcdir)/qkeysequenceedit-rb.hpp $(srcdir)/qlabel-rb.hpp $(srcdir)/qlayout-rb.hpp $(srcdir)/qlayoutitem-rb.hpp $(srcdir)/qlcdnumber-rb.hpp $(srcdir)/qlineedit-rb.hpp $(srcdir)/qlistview-rb.hpp $(srcdir)/qlistwidget-rb.hpp $(srcdir)/qmainwindow-rb.hpp $(srcdir)/qmdiarea-rb.hpp $(srcdir)/qmdisubwindow-rb.hpp $(srcdir)/qmenu-rb.hpp $(srcdir)/qmenubar-rb.hpp $(srcdir)/qmessagebox-rb.hpp $(srcdir)/qplaintextedit-rb.hpp $(srcdir)/qprogressbar-rb.hpp $(srcdir)/qprogressdialog-rb.hpp $(srcdir)/qpushbutton-rb.hpp $(srcdir)/qradiobutton-rb.hpp $(srcdir)/qrubberband-rb.hpp $(srcdir)/qscrollarea-rb.hpp $(srcdir)/qscrollbar-rb.hpp $(srcdir)/qsizegrip-rb.hpp $(srcdir)/qsizepolicy-rb.hpp $(srcdir)/qslider-rb.hpp $(srcdir)/qspinbox-rb.hpp $(srcdir)/qsplashscreen-rb.hpp $(srcdir)/qsplitter-rb.hpp $(srcdir)/qstackedlayout-rb.hpp $(srcdir)/qstackedwidget-rb.hpp $(srcdir)/qstatusbar-rb.hpp $(srcdir)/qstyle-rb.hpp $(srcdir)/qstyleditemdelegate-rb.hpp $(srcdir)/qstylefactory-rb.hpp $(srcdir)/qstyleoption-rb.hpp $(srcdir)/qsystemtrayicon-rb.hpp $(srcdir)/qtabbar-rb.hpp $(srcdir)/qtableview-rb.hpp $(srcdir)/qtablewidget-rb.hpp $(srcdir)/qtabwidget-rb.hpp $(srcdir)/qtextbrowser-rb.hpp $(srcdir)/qtextedit-rb.hpp $(srcdir)/qtoolbar-rb.hpp $(srcdir)/qtoolbox-rb.hpp $(srcdir)/qtoolbutton-rb.hpp $(srcdir)/qtooltip-rb.hpp $(srcdir)/qtreeview-rb.hpp $(srcdir)/qtreewidget-rb.hpp $(srcdir)/qtwidgets-rb.hpp $(srcdir)/qtwidgetspreludes-rb.hpp $(srcdir)/qtwidgetsversion-rb.hpp $(srcdir)/qundoview-rb.hpp $(srcdir)/qwidget-rb.hpp $(srcdir)/qwizard-rb.hpp $(srcdir)/t-qtwidgets-rb.hpp
LOCAL_HDRS = 
TARGET = qtwidgets
TARGET_NAME = qtwidgets
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
TARGET_SO_DIR_TIMESTAMP = $(TIMESTAMP_DIR)/.sitearchdir.-.qt6.-.qtwidgets.time

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
	$(ECHO) linking shared-object qt6/qtwidgets/$(DLLIB)
	-$(Q)$(RM) $(@)
	$(Q) $(LDSHAREDXX) -o $@ $(OBJS) $(LIBPATH) $(DLDFLAGS) $(LOCAL_LIBS) $(LIBS)



$(OBJS): $(HDRS) $(ruby_headers)
