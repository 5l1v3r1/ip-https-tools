local nmap = require 'nmap'
local comm = require 'comm'
local string = require 'string'
local stdnse = require 'stdnse'
local shortport = require 'shortport'
local sslcert = require 'sslcert'

description = [[
tl;dr:
IP-HTTPS sends Teredo related IPv6 packets over an IPv4-based HTTPS session.

Checks if the IP over HTTPS (IP-HTTPS) Tunneling Protocol [1] is supported. This
indicates that Microsoft DirectAccess [2], which allows remote clients to access
intranet resources on a domain basis, is supported. Windows clients need
Windows 7 Enterprise/Ultime or Windows 8.1 Enterprise/Ultimate. Servers need
Windows Server 2008 (R2) or Windows Server 2012 (R2). Older versions
of Windows and Windows Server are not supported.

[1] http://msdn.microsoft.com/en-us/library/dd358571.aspx
[2] http://technet.microsoft.com/en-us/network/dd420463.aspx
]]

author = "Niklaus Schiess <nschiess@adversec.com>"
categories = {'discovery', 'default'}

---
--@output
-- 443/tcp open  https
-- |_ip-https-discover: IP-HTTPS is supported. This indicates that this host supports Microsoft DirectAccess.
--@xmloutput
-- true

portrule = function(host, port)
  return shortport.http(host, port) and shortport.ssl(host, port)
end

-- Tested on a Windows Server 2012 R2 DirectAccess deployment. The URI
-- /IPTLS from the specification (see description) doesn't seem to work
-- on recent versions. They may be related to Windows Server 2008 (R2).
local request =
'POST /IPHTTPS HTTP/1.1\r\n' ..
'Host: %s\r\n' ..
'Content-Length: 18446744073709551615\r\n\r\n'

action = function(host, port)
  local target
  if host.targetname then
    target = host.targetname
  else
    -- If there is no targetname, take the subject commonName from the SSL cert.
    local status,cert = sslcert.getCertificate(host,port)
    if not status then
      stdnse.print_debug("%s: Could not retrieve SSL certificate", SCRIPT_NAME)
      return
    end
    target = cert.subject['commonName']
  end
  if not target then
    return
  end
  local socket, response = comm.tryssl(host,port,
    string.format(request, target),
    { timeout=3000, lines=4 })
  if not socket then
    stdnse.print_debug("%s: Problem establishing connection: %s", SCRIPT_NAME, response)
    return nil
  end
  socket:close()

  if string.match(response, 'HTTP/1.1 200') then
    return true, 'IP-HTTPS is supported. This indicates that this host supports Microsoft DirectAccess.'
  end
  return nil
end