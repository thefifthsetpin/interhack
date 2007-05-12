# this is for helping you manage a dual slow digestion game
# can turn it on and off with new extcmd #dualsd
# by Eidolos

my $last_mod20 = -1;
our $dual_sd_enabled = 0;

extended_command "#dualsd"
              => sub
                 {
                   # the "if" is to guard against ^P toggling
                   $dual_sd_enabled = not $dual_sd_enabled
                     if substr($&, 0, 3) eq "\e[H";
                   "Slow digestion notification "
                   . ($dual_sd_enabled ? "ON." : "OFF.")
                 };

each_iteration
{
    if (/ T:(\d+)/)
    {{
        my $mod20 = $1 % 20;

        # avoid saying the same thing twice in case of redraw or what have you
        last if $mod20 == $last_mod20;
        $last_mod20 = $mod20;

        last if not $dual_sd_enabled;

           if ($mod20 == 3)  { annotate("Remove your left =oSD.")  }
        elsif ($mod20 == 5)  { annotate("Put on your left =oSD.")  }
        elsif ($mod20 == 11) { annotate("Remove your right =oSD.") }
        elsif ($mod20 == 13) { annotate("Put on your right =oSD.") }
    }}
}

