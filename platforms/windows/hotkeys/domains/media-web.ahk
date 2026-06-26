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

#hotif winactive(exeMsEdge)
!1::{
trackDomainsHotkeyUsage("!1", "edge")
services.dynamic.openEdgeReadAloud()
}

#hotif winactive(titleChatGpt)
f12::{
trackDomainsHotkeyUsage("f12", "chatgpt")
services.dynamic.clearChatAndSend()
}

#hotif winactive("nttdata-EA")
f1::{
trackDomainsHotkeyUsage("f1", "nttdata")
services.dynamic.fillNttOfficeCredentials()
}

#hotif

