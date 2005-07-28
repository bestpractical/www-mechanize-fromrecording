use inc::Module::Install;

name ('WWW-Mechanize-FromRecording');
author ('David Glasser <glasser@bestpractical.com>');
version_from ('lib/WWW/Mechanize/FromRecording.pm');
abstract_from('lib/WWW/Mechanize/FromRecording.pm');
license('perl');
requires('Test::More');

&WriteAll;
