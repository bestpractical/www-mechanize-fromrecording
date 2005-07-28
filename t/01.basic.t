#!perl

use strict;
use warnings;

use Test::More 'no_plan';

BEGIN { use_ok 'WWW::Mechanize::FromRecording' }

my $PM = WWW::Mechanize::FromRecording->new('t/basic_recorded/basic');
isa_ok($PM, 'WWW::Mechanize::FromRecording');

my $script = $PM->mech_script;

like($script, qr/my \$mech = WWW::Mechanize->new;/);

warn $script;

