#hotif winactive(exeVlc)
d::{
trackDomainsHotkeyUsage("d", "vlc")
Send("]")
}
s::{
trackDomainsHotkeyUsage("s", "vlc")
Send("[")
}

#hotif winactive(exeFirefox)
^+n::{
trackDomainsHotkeyUsage("^+n", "firefox")
Send("^+p")
}

#hotif
