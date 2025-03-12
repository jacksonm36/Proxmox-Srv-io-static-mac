[Unit]
Description=Fix MAC addresses after SR-IOV setup
After=sriov.service network-online.target
Wants=network-online.target
Requires=sriov.service

[Service]
Type=oneshot
ExecStart=/bin/bash /root/hookscript-srv-io/vf_add_maddr.sh # change this to your folder where you store your sh script
RemainAfterExit=yes
StandardOutput=journal
StandardError=journal
TimeoutStartSec=30

[Install]
WantedBy=multi-user.target
