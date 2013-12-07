use 5.012004;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'NexStarCtl',
    VERSION_FROM      => 'lib/NexStarCtl.pm', # finds $VERSION
    PM                => { 'nexstarctl/nexstarctl.pl' => '$(INST_BIN)/nexstarctl',
                           'lib/NexStarCtl.pm' => '$(INST_LIB)/NexStarCtl.pm'
                         },
    BUILD_REQUIRES    => { 'Device::SerialPort' => 0.1 },
    PREREQ_PM         => { 'Device::SerialPort' => 0.1 }, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT  => 'NexStarCtl - API to control NexStar compatible telescopes',
       AUTHOR         => 'Rumen Bogdanovski <rumen@skyarchive.org>') : ()),
);
