#
# Copyright (C) 2011-2012  stfn <stfnmd@gmail.com>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

#
# Development is currently hosted at
# https://github.com/stfnm/weechat-scripts
#

use strict;
use warnings;
use CGI;

my %SCRIPT = (
	name => 'isgd',
	author => 'stfn <stfnmd@gmail.com>',
	version => '0.2',
	license => 'GPL3',
	desc => 'Shorten URLs with is.gd on command',
	opt => 'plugins.var.perl',
);
my %OPTIONS = (
	color => 'white', # color used for printing short URLs
);
my $SHORTENER_URL = "http://is.gd/create.php?format=simple&url=";
my $TIMEOUT = 30 * 1000;
my %LOOKUP;

weechat::register($SCRIPT{"name"}, $SCRIPT{"author"}, $SCRIPT{"version"}, $SCRIPT{"license"}, $SCRIPT{"desc"}, "", "");
weechat::hook_command($SCRIPT{"name"}, $SCRIPT{"desc"},
	                    "[<URL> ...]\n" .
	"                    [<number>]\n",
	"   URL: URL to shorten (multiple URLs may be given)\n" .
	"number: shorten up to n last found URLs in current buffer\n\n" .
	"Without any URL arguments, the last found URL in the current buffer will be shortened.\n\n" .
	"Examples:\n" .
	"  /isgd http://google.de\n" .
	"  /isgd 3",
	"", "command_cb", "");

init_config();

sub command_cb
{
	my ($data, $buffer, $args) = @_;
	my @URLs;

	# If URLs were provided in command arguments, shorten them
	while ($args =~ m{(https?://\S+)}gi) {
		push(@URLs, $1);
	}
	# Otherwise search backwards in lines of current buffer
	if (@URLs == 0) {
		my $count = 1;
		$count = $1 if ($args =~ /^(\d+)$/);
		my $infolist = weechat::infolist_get("buffer_lines", $buffer, "");
		while (weechat::infolist_prev($infolist) == 1) {
			my $message = weechat::infolist_string($infolist, "message");
			while ($message =~ m{(https?://\S+)}gi) {
				my $url = $1;
				push(@URLs, $url) unless ($url =~ m{^https?://is\.gd/}gi);
			}
			last if (@URLs >= $count);
		}
		weechat::infolist_free($infolist);
	}

	foreach (@URLs) {
		my $cmd = "url:$SHORTENER_URL" . CGI::escape($_);
		$LOOKUP{$cmd} = $_;
		weechat::hook_process($cmd, $TIMEOUT, "process_cb", $buffer);
	}

	return weechat::WEECHAT_RC_OK;
}

sub process_cb
{
	my ($data, $command, $return_code, $out, $err) = @_;
	my $buffer = $data;

	if ($return_code == 0 && $out) {
		my $domain = "";
		$domain = $1 if ($LOOKUP{$command} =~  m{^https?://([^/]+)}gi);
		weechat::print_date_tags($buffer, 0, "no_log", weechat::color($OPTIONS{color}) . "$out ($domain)");
	}

	return weechat::WEECHAT_RC_OK;
}

sub init_config
{
	weechat::hook_config("$SCRIPT{'opt'}.$SCRIPT{'name'}.*", "config_cb", "");
	foreach my $option (keys %OPTIONS) {
		if (!weechat::config_is_set_plugin($option)) {
			weechat::config_set_plugin($option, $OPTIONS{$option});
		} else {
			$OPTIONS{$option} = weechat::config_get_plugin($option);
		}
	}
}

sub config_cb
{
	my ($pointer, $name, $value) = @_;
	$name = substr($name, length("$SCRIPT{'opt'}.$SCRIPT{'name'}."), length($name));
	$OPTIONS{$name} = $value;

	return weechat::WEECHAT_RC_OK;
}
