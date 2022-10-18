#!/bin/bash

sudo systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target
sudo sed -i -e 's/#HandleLidSwitch=suspend/HandleLidSwitch=ignore/g' -e 's/#IdleAction=ignore/IdleAction=ignore/g'
