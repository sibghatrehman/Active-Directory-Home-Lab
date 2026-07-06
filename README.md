Overview
This lab simulates a small business network with a single domain controller and a domain-joined client. The goal was to go beyond just following a tutorial and actually verify, break, and fix things the way an on-the-job admin would — including a real NTFS-vs-share-permission conflict encountered and resolved during the build.

Domain	mydomain.com
Domain Controller	Windows Server 2022 — AD DS, DNS, DHCP, RAS/NAT
Client	Windows 10 — domain-joined
Hypervisor	Oracle VirtualBox
Internal network	172.16.0.0/24 (VirtualBox "Internal Network" / intnet)
Architecture
DC01 runs two NICs: one on NAT (for internet access via the home router), one on an isolated Internal Network handing out addressing for the lab.
DC01 acts as the router for the internal subnet (RAS/NAT), DNS server, and DHCP server (scope 172.16.0.100–.200).
Client1 sits entirely on the internal network and pulls its IP, gateway, and DNS from DC01 via DHCP.
Full IP scheme, OU layout, and DHCP scope details are in the diagram above.
Build Steps
1. Domain Controller Setup
Windows Server 2022 VM — 4 GB RAM, 4 vCPU, 15 GB HDD, 2 NICs (NAT + Internal Network)
Installed Guest Additions for a usable console
Configured the Internal NIC statically: 172.16.0.1 / 255.255.255.0, DNS 127.0.0.1
Promoted the server to a Domain Controller (AD DS role → mydomain.com)
2. Active Directory Structure
Created _ADMINS OU with a dedicated admin account, added to Domain Admins (best practice: never use the built-in Administrator day-to-day)
Created _USERS OU with three sub-OUs: IT, HR, Management
Bulk-created 1,000+ user accounts with PowerShell, distributed across the three department OUs (see Create-Users.ps1)
3. Routing (RAS/NAT)
Added the Remote Access role, configured NAT under Routing and Remote Access
Assigned the NAT-facing NIC as the internet-facing adapter so Client1 can reach the internet through DC01
4. DHCP
Added the DHCP role, created a scope for 172.16.0.100–.200 /24
Set Option 3 (Router) and Option 6 (DNS) to 172.16.0.1
Authorized the scope in AD
5. Client Setup
Windows 10 VM on the Internal Network only
Confirmed it received an address from DC01 via DHCP (ipconfig /all)
Renamed the machine, joined it to mydomain.com, rebooted
6. Group Policy
Three GPOs created and linked to the _USERS OU:

Password Complexity Policy — enforces strong password requirements
USB Restriction Policy — denies all removable storage
Desktop Wallpaper Enforcement — pushes a standard corporate wallpaper
Verification: ran gpresult /r on Client1 to confirm all three policies show as applied, then tested each in practice (plugged in a USB drive, checked wallpaper, attempted a weak password).

7. File Sharing & Troubleshooting
Created a shared folder on DC01 to test file-server access for a standard domain user (srehman).

Issue hit: user could see the share over the network but got "You don't have permission... contact your network administrator" when opening it.

Root cause: Windows applies the more restrictive of two separate ACLs — share permissions and NTFS permissions. The share itself was open, but the underlying NTFS ACL only granted access to Administrators/SYSTEM.

Fix:

Share tab → Advanced Sharing → Permissions → granted Domain Users Read/Change
Security tab (NTFS) → added Domain Users, granted Read & Execute
Had the user log off/on to refresh their token, then confirmed access
Scripts
Create-Users.ps1 — reads names.txt (Full Name,Department), creates the OU structure, and bulk-provisions users into the correct department OU. Handles duplicate sAMAccountName collisions automatically.
names.txt — sample data set (1,000+ names) split across IT / HR / Management.
Skills Demonstrated
Active Directory Domain Services · DNS/DHCP · Group Policy Management · PowerShell Scripting · NTFS & Share Permissions · Windows Server 2022 · VirtualBox · Troubleshooting

Screenshots
Screenshots are attached in GITHUB Repo
- **Follow-up project:** this lab has a companion — [hybrid-identity-lab](https://github.com/sibghatrehman/hybrid-identity-entra-connect.git) — which syncs these OU users to Microsoft Entra ID


Resources Used
Josh Madakor — How to Setup a Basic Home Lab Running Active Directory (Oracle VirtualBox) — the primary walkthrough for the AD DS build and bulk user creation via PowerShell
Server Academy — Group Policy Tutorial for Beginners — used for GPO creation and linking
Microsoft Learn — official Group Policy documentation, used as a reference for SYSVOL replication and GPO inheritance behavior
Notes / Next Steps
Fix the DHCP gateway typo carried over from early notes (172.168.0.1 → should be 172.16.0.1) if you're following along from the raw notes
Possible extensions: add a second DC for replication practice, stand up a file server role separately from the DC, or add a Conditional Access / MFA layer with Azure AD Connect for a hybrid identity lab






