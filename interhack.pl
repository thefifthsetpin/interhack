#!/usr/bin/perl
use strict;
use lib 'lib';
use Term::ReadKey;
use IO::Socket;
use LWP::Simple;
use File::Temp qw/tempfile/;

# CONFIG
our $nick = '';
our $pass = '';
our $server = 'nethack.alt.org';
# END CONFIG

our $autologin = !grep {$_ eq "-l"} @ARGV;
our %keymap;
our @colormap;
our @repmap;
our @annomap;
our @tabmap;

use Interhack::Config;
Interhack::Config::run();

my $sock = new IO::Socket::INET(PeerAddr => $server,
                                PeerPort => 23,
                                Proto => 'tcp');
die "Could not create socket: $!\n" unless $sock;
$sock->blocking(0);

my $IAC = chr(255);
my $SB = chr(250);
my $SE = chr(240);
my $WILL = chr(251);
my $WONT = chr(252);
my $DO = chr(253);
my $DONT = chr(254);
my $TTYPE = chr(24);
my $TSPEED = chr(32);
my $XDISPLOC = chr(35);
my $NEWENVIRON = chr(39);
my $IS = chr(0);
my $GOAHEAD = chr(3);
my $ECHO = chr(1);
my $NAWS = chr(31);
my $STATUS = chr(5);
my $LFLOW = chr(33);
my $LINEMODE = chr(34);

print {$sock}"$IAC$WILL$TTYPE"
            ."$IAC$SB$TTYPE${IS}xterm-color$IAC$SE"
            ."$IAC$WONT$TSPEED"
            ."$IAC$WONT$XDISPLOC"
            ."$IAC$WONT$NEWENVIRON"
            ."$IAC$DONT$GOAHEAD"
            ."$IAC$WILL$ECHO"
            ."$IAC$DO$STATUS"
            ."$IAC$WILL$LFLOW"
            ."$IAC$WILL$NAWS"
            ."$IAC$SB$NAWS$IS".chr(80).$IS.chr(24)."$IAC$SE";

# autologin
if ($autologin && $nick ne '')
{
  print {$sock} "l$nick\n";
  if ($pass ne '')
  {
    print {$sock} "$pass\n";
  }
}

ReadMode 3;
END { ReadMode 0 }
$|++;

my $responses_so_far = '';
my $response_this_play = 1;
my $tab = "\t";
my $me;
my $at_login = 0;
my $postprint = '';
my $annotation_onscreen = 0;
my $stop_sing_pass = 0;

# clear socket buffer (responses to telnet negotiation, name/pass echoes, etc
until (defined(recv($sock, $_, 1024, 0)) && /zaphod\.alt\.org/) {}

sub xp_str
{
  my ($level, $total_exp) = @_;
  my $length = length $total_exp;

  my $exp_needed = $level < 11 ? 10     * 2 ** $level
                 : $level < 21 ? 10_000 * 2 ** $level
                 : 10_000_000 * ($level - 19);

  $exp_needed -= $total_exp;


  if (length($exp_needed)-1 > $length)
  {
    return "Xp:$level!$total_exp";
  }
  else
  {
    $length++;
    return sprintf "X:%dn%-${length}s", $level, $exp_needed;
  }
}

sub hpmon
{
  my ($pre, $text, $cur, $max) = @_;
  my $color = '';

  # prayer point
  if ($cur * 7 <= $max || $cur <= 6)
  {
    $color = "\e[1;30m";
  }
  elsif ($cur >= $max) { }
  elsif ($cur * 2 >= $max)
  {
    $color = "\e[1;32m";
  }
  elsif ($cur * 3 >= $max)
  {
    $color = "\e[1;33m";
  }
  elsif ($cur * 4 >= $max)
  {
    $color = "\e[0;31m";
  }
  elsif ($cur * 5 >= $max)
  {
    $color = "\e[1;31m";
  }

  "$pre$color$text\e[0m"
}

sub annotate
{
  my $annotation = shift;
  $annotation_onscreen = 1;
  $postprint .= "\e[s\e[2H\e[1;30m$annotation\e[0m\e[u";
}

sub tab
{
  my $string = shift;
  my $msg = @_ ? shift : "Press tab to send the string: ";
  $tab = $string;
  $string =~ s/\n/\\n/g;
  annotate("$msg$string");
}

ITER:
while (1)
{
  # read from stdin, print to sock
  if (defined(my $c = ReadKey -1))
  {
    if ($c eq "\t" && $at_login)
    {
      print "\e[1;30mPlease wait while I download the existing rcfile.\e[0m";
      my $nethackrc = get("http://alt.org/nethack/rcfiles/$me.nethackrc");
      my ($fh, $name) = tempfile();
      print {$fh} $nethackrc;
      close $fh;
      my $t = (stat $name)[9];
      $ENV{EDITOR} = 'vi' unless exists $ENV{EDITOR};
      system("$ENV{EDITOR} $name");

      # file wasn't modified, so silently bail
      if ($t == (stat $name)[9])
      {
        print {$sock} ' ';
        next ITER;
      }

      $nethackrc = do { local (@ARGV, $/) = $name; <> };
      if ($nethackrc eq '')
      {
        print "\e[24H\e[1;30mYour nethackrc came out empty, so I'm bailing.--More--";
        ReadKey 0;
      }
      else
      {
        print "\e[24H\e[1;30mPlease wait while I update the serverside rcfile.";
        print {$sock} "o:0\n1000ddi";
        print {$sock} "$nethackrc\eg";
        until (defined(recv($sock, $_, 1024, 0)) && /\e\[.*?'g' is not implemented/) {}
        print {$sock} ":wq\n";
      }
    }

    if ($tab ne "\t")
    {
      ($responses_so_far, $response_this_play) = ('', 1)
        and next ITER
          if $c eq "'";

      $c = $tab if $c eq "\t";
      $tab = "\t";
      #$c .= chr(18); # refresh screen
    }
    elsif (exists $keymap{$c})
    {
      $c = $keymap{$c};
    }

    print {$sock} $c;
    print "\e[s\e[2H\e[K\e[u" if $annotation_onscreen;
    $at_login = 0;
    $annotation_onscreen = 0;
  }

  # read from sock, print to stdout
  if (defined(recv($sock, $_, 1024, 0)))
  {
    unless ($stop_sing_pass)
    {
      s/\Q$pass//g;
    }

    if (/Logged in as: (\w+)/)
    {
      $stop_sing_pass = 1;
      $at_login = 1;
      $me = $1;
    }

    if ($at_login)
    {
      s/(o\) Edit option file)/$1 \e[1;30mTab) .. locally\e[0m/;
    }

    foreach my $map (@repmap)
    {
      $map->();
    }

    foreach my $annomap (@annomap)
    {
      annotate($annomap->[1])
        if $_ =~ $annomap->[0];
    }

    # make floating eyes bright cyan
    s{\e\[(?:0;)?34m((?:\x0f)?e)(?! - )}{\e[1;36m$1}g;

    if (/\e\[HYou hear (\d) tumblers? click and (\d) gears? turn\./)
    {
      $responses_so_far .= " $2$1";
      $response_this_play = 1;
    }
    elsif (/\e\[HYou hear (\d) tumblers? click\./)
    {
      $responses_so_far .= " 0$1";
      $response_this_play = 1;
    }
    elsif (/\e\[HYou hear (\d) gears? turn\./)
    {
      $responses_so_far .= " ${1}0";
      $response_this_play = 1;
    }
    elsif (/\e\[HWhat tune are you playing\?/)
    {
      $responses_so_far .= " 00" unless $response_this_play;
      $response_this_play = 0;
      my $next = `./automastermind $responses_so_far`;
      if ($next =~ 'ACK')
      {
        ($responses_so_far, $response_this_play) = ('', 1);
        annotate("No possible tunes. Resetting.");
      }
      else
      {
        ($next) = $next =~ /^([A-G]{5})/;
        tab("$next\n", "Press ' to reset, tab to send the string: ");
      }
    }

    for my $tabmap (@tabmap)
    {
      tab($tabmap->[1])
        if $_ =~ $tabmap->[0];
    }

    foreach my $map (@colormap)
    {
      s{$map->[0]}{$map->[1]$&\e[0m}g;
    }

    # display Xp needed for next level
    s{Xp:(\d+)\/(\d+)}{xp_str($1, $2)}eg;

    # highlight "high priest of Foo" except when Foo = Moloch
    s{high priest of (?!Moloch)\S+}{\e[1;31m$&\e[0m}g;

    # HPmon done right
    s{(\e\[24;\d+H)((\d+)\((\d+)\))}{hpmon($1, $2, $3, $4)}eg;
    s{HP:((-?\d+)\((-?\d+)\))}{hpmon("HP:", $1, $2, $3)}eg;

    # power colors!
    s{Pw:((-?\d+)\((-?\d+)\))}{
      my $color = '';

      if ($2 >= $3) { }
      elsif ($2 * 2 >= $3)
      {
        $color = "\e[1;36m";
      }
      elsif ($2 * 3 >= $3)
      {
        $color = "\e[1;35m";
      }
      else
      {
        $color = "\e[0;35m";
      }

      "Pw:$color$1\e[0m"
      }eg;
    print;
    print $postprint and $postprint = ''
      if $postprint ne '';
  }
}

