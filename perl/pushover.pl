#
# Copyright (C) 2013 stfn <stfnmd@gmail.com>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <http://www.gnu.org/licenses/>.
#

#
# Development is currently hosted at
# https://github.com/stfnm/weechat-scripts
#

use strict;
use warnings;
use CGI;

my %SCRIPT = (
	name => 'pushover',
	author => 'stfn <stfnmd@gmail.com>',
	version => '0.1',
	license => 'GPL3',
	desc => 'Send real-time push notifications to your mobile devices using pushover.net',
	opt => 'plugins.var.perl',
);
my %OPTIONS_DEFAULT = (
	'token' => ['', 'API Token/Key'],
	'user' => ['', "User Key"],
	'sound' => ['', "Sound (empty for default)"],
	'show_highlights' => ['on', 'Notify on highlights'],
	'show_priv_msg' => ['on', 'Notify on private messages'],
	'only_if_away' => ['off', 'Notify only if away status is active'],
);
my %OPTIONS = ();

# Register script and setup hooks
weechat::register($SCRIPT{"name"}, $SCRIPT{"author"}, $SCRIPT{"version"}, $SCRIPT{"license"}, $SCRIPT{"desc"}, "", "");
weechat::hook_print("", "irc_privmsg", "", 1, "print_cb", "");
init_config();

#
# Handle config stuff
#
sub init_config
{
	weechat::hook_config("$SCRIPT{'opt'}.$SCRIPT{'name'}.*", "config_cb", "");
	my $version = weechat::info_get("version_number", "") || 0;
	foreach my $option (keys %OPTIONS_DEFAULT) {
		if (!weechat::config_is_set_plugin($option)) {
			weechat::config_set_plugin($option, $OPTIONS_DEFAULT{$option}[0]);
			$OPTIONS{$option} = $OPTIONS_DEFAULT{$option}[0];
		} else {
			$OPTIONS{$option} = weechat::config_get_plugin($option);
		}
		if ($version >= 0x00030500) {
			weechat::config_set_desc_plugin($option, $OPTIONS_DEFAULT{$option}[1]." (default: \"".$OPTIONS_DEFAULT{$option}[0]."\")");
		}
	}
}
sub config_cb
{
	my ($pointer, $name, $value) = @_;
	$name = substr($name, length("$SCRIPT{opt}.$SCRIPT{name}."), length($name));
	$OPTIONS{$name} = $value;
	return weechat::WEECHAT_RC_OK;
}

#
# Send to pushover.net
#
sub pushover
{
	my ($token, $user, $sound, $message) = @_;

	my @post = (
		"token=$token",
		"user=$user",
		"message=" . CGI::escape($message),
	);
	push(@post, "sound=$sound") if ($sound && length($sound) > 0);

	# Send POST request
	my $hash = { "post"  => 1, "postfields" => join(";", @post) };
	weechat::hook_process_hashtable("url:https://api.pushover.net/1/messages.json", $hash, 20 * 1000, "", "");
	#weechat::print("", "[$SCRIPT{name}] debug: postfields -> @post, msg -> $message");

	return weechat::WEECHAT_RC_OK;
}

#
# Notification wrapper
#
sub notify
{
	my $msg = $_[0];
	pushover($OPTIONS{token}, $OPTIONS{user}, $OPTIONS{sound}, $msg);
}

#
# Catch printed messages
#
sub print_cb
{
	my ($data, $buffer, $date, $tags, $displayed, $highlight, $prefix, $message) = @_;

	my $buffer_type = weechat::buffer_get_string($buffer, "localvar_type");
	my $away_msg = weechat::buffer_get_string($buffer, "localvar_away");
	my $away = ($away_msg && length($away_msg) > 0) ? 1 : 0;

	if ($OPTIONS{show_priv_msg} eq "on" && $buffer_type eq "private") {
		# Private message
		if ($OPTIONS{only_if_away} eq "off" || $away) {
			notify("<$prefix> $message");
		}
	} elsif ($OPTIONS{show_highlights} eq "on" && $highlight == 1) {
		# Highlight
		if ($OPTIONS{only_if_away} eq "off" || $away) {
			notify("<$prefix> $message");
		}
	}

	return weechat::WEECHAT_RC_OK;
}
