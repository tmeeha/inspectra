#!/usr/bin/env perl
# Serve this folder on http://localhost and open it in the default browser (macOS / Linux).
# Listens on this computer only (127.0.0.1). Press Ctrl+C or close the window to stop.
# Options: --port N (first port to try, default 8000), --no-browser.
use strict;
use warnings;
use IO::Socket::INET;
use File::Basename qw(dirname);
use Cwd qw(abs_path);

$| = 1;
my ($first, $browser) = (8000, 1);
while (my $a = shift @ARGV) {
  if ($a eq '--no-browser') { $browser = 0 }
  elsif ($a eq '--port') { $first = int(shift(@ARGV) // 8000) }
}
my $root = abs_path(dirname(abs_path($0)));
my %mime = (
  html => 'text/html; charset=utf-8', htm => 'text/html; charset=utf-8', js => 'text/javascript; charset=utf-8',
  mjs => 'text/javascript; charset=utf-8', css => 'text/css; charset=utf-8', json => 'application/json',
  md => 'text/markdown; charset=utf-8', txt => 'text/plain; charset=utf-8', csv => 'text/csv; charset=utf-8',
  wav => 'audio/wav', png => 'image/png', svg => 'image/svg+xml', ico => 'image/x-icon', pdf => 'application/pdf',
);

my ($srv, $port);
for my $p ($first .. $first + 49) {
  $srv = IO::Socket::INET->new(Listen => 20, LocalAddr => '127.0.0.1', LocalPort => $p, Proto => 'tcp', ReuseAddr => 1);
  if ($srv) { $port = $p; last }
}
die "Could not find a free port from $first to " . ($first + 49) . ".\n" unless $srv;

my $url = "http://localhost:$port/";
print "Serving $root\nOpen $url  (this computer only)\nPress Ctrl+C or close this window to stop.\n";
if ($browser) {
  my $pid = fork();
  if (defined $pid && $pid == 0) {
    sleep 1;
    exec($^O eq 'darwin' ? 'open' : 'xdg-open', $url);
    exit 0;
  }
}
$SIG{CHLD} = 'IGNORE';
$SIG{PIPE} = 'IGNORE';

sub reply {
  my ($c, $code, $text, $type, $body, $head) = @_;
  print $c "HTTP/1.1 $code $text\r\nContent-Type: $type\r\nContent-Length: " . length($body) .
    "\r\nCache-Control: no-cache\r\nConnection: close\r\n\r\n";
  print $c $body unless $head;
}

sub handle {
  my ($c) = @_;
  binmode $c;
  local $SIG{ALRM} = sub { exit 0 };
  alarm 15;
  my $line = <$c>;
  return unless defined $line && $line =~ m{^(GET|HEAD)\s+(\S+)\s+HTTP/}i;
  my ($method, $target) = (uc $1, $2);
  while (defined(my $h = <$c>)) { last if $h =~ /^\r?\n$/ }       # skip the headers
  alarm 0;
  (my $path = $target) =~ s/[?#].*//;
  $path =~ s/%([0-9A-Fa-f]{2})/chr(hex($1))/ge;
  my @seg = grep { length } split m{/}, $path;
  if ($path =~ /\0/ || grep { /^\./ } @seg) { return reply($c, 404, 'Not Found', 'text/plain', "Not found\n", $method eq 'HEAD') }
  my $file = join('/', $root, @seg);
  $file .= '/index.html' if -d $file;
  my $real = -f $file ? abs_path($file) : undef;
  unless (defined $real && index($real, "$root/") == 0) {
    return reply($c, 404, 'Not Found', 'text/plain', "Not found\n", $method eq 'HEAD');
  }
  open(my $fh, '<:raw', $real) or return reply($c, 404, 'Not Found', 'text/plain', "Not found\n", $method eq 'HEAD');
  local $/; my $body = <$fh>; close $fh;
  my ($ext) = $real =~ /\.([^.\/]+)$/;
  reply($c, 200, 'OK', $mime{lc($ext // '')} // 'application/octet-stream', $body, $method eq 'HEAD');
}

while (my $c = $srv->accept) {
  my $pid = fork();
  if (defined $pid && $pid == 0) { close $srv; eval { handle($c) }; close $c; exit 0 }
  close $c;
}
