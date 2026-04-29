# Utils
## File Management
alias ls="eza --group-directories-first"
alias ll="ls -l $@"
alias la="ll -ag $@"
alias t="ll -T $@"
alias t2="t -L 2 $@"
alias t3="t -L 3 $@"
alias rm='trash-put'
alias te='trash-empty'
alias cp='cp -i'

## Directories
alias dl='cd ~/Downloads'
alias tn='tmux new'
alias ta='tmux attach'
alias b='bat'
alias batcat='bat'
alias c='code'
alias C='code .'
alias p='python'
alias tmp='pushd $(mktemp -d)'
# Trick to have ALL aliases available with sudo <3
alias sudo='sudo ' 
alias ..="cd ../"
alias ....="cd ../../"
alias ......="cd ../../../"
alias ........="cd ../../../../"

## Git
gic() { 
  git add .
  git commit -a -m "$*"
  git push
}
alias git="GIT_SSL_NO_VERIFY=true git"
alias gaa="git add *"
alias ga="git add"
alias gps="git push"
alias gpl="git pull"
alias gdh='git diff HEAD'

## Networking
alias ipa="ip -br a | grep -vF DOWN"
alias ipaa="ip -br a"
alias nc='ncat'
alias ncl='ncat -lnvp'
alias ssh-yolo='ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no'
alias wifi-nmtui='nmtui'
alias wget-yolo="wget --no-check-certificate"
alias digall='f(){ dig +answer +multiline "$1" any @8.8.8.8;  unset -f f; }; f'
alias ipv6-disable='sudo sysctl -w net.ipv6.conf.all.disable_ipv6=1; sudo sysctl -w net.ipv6.conf.default.disable_ipv6=1; sudo sysctl -w net.ipv6.conf.lo.disable_ipv6=1'
alias ipv6-enable='sudo sysctl -w net.ipv6.conf.all.disable_ipv6=0; sudo sysctl -w net.ipv6.conf.default.disable_ipv6=0; sudo sysctl -w net.ipv6.conf.lo.disable_ipv6=0'
alias dns-127='echo "nameserver 127.0.0.1" | sudo tee /etc/resolv.conf'
alias dns-1='echo "nameserver 1.1.1.1" | sudo tee /etc/resolv.conf'
alias dns-8='echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf'
alias dns-9='echo "nameserver 9.9.9.9" | sudo tee /etc/resolv.conf'
alias get-ip='curl -sS ipinfo.io/ip ; echo'
alias get-ip-cpy='curl -sS ipinfo.io/ip | cpy'

## Video, Audio
alias flameshotz='while true; do flameshot full -p ~/Downloads; sleep 1; done'

# Monitoring, Upload, Sleep
alias df="df -h"
alias show-disk-io='watch -cd -- iostat -h'
alias sdi='show-disk-io'
alias show-open-ports="sudo ss -latepun | grep -i listen"
alias sop='show-open-ports'
alias get-du='du -ch -d 1'
alias get-pid-click='xprop _NET_WM_PID | cut -d" " -f3'
alias get-pid-ps='ps fauxw | fzf | awk "{ print \$2}"'
alias get-shell-size='echo "stty rows $LINES cols $COLUMNS"'
alias dirmon='inotifywait -rm -e create -e moved_to -e modify -e access -e attrib -e close_write -e moved_from'
alias killit='sudo kill -KILL'

## Misc
alias usleep='f(){ python3 -c "import time; time.sleep($1)";  unset -f f; }; f'
alias vplay='mplayer -nosound'
alias b64d='base64 -d'
alias b64e='base64 -w 0'
alias cgrep='grep --color=always'
alias clean-swap='sudo swapoff -a && sudo swapon -a'
alias cpy='xclip -selection clipboard'
alias paste='xclip -selection clipboard -o'
alias lbt-keyboard-layout='f(){ gsettings set org.gnome.desktop.input-sources sources "[(\"xkb\", \"$1\")]" ;  unset -f f; }; f'
alias encrypt='f(){ PASS=$(cat /dev/urandom | base64 | head -c 20) && echo "$PASS" | xclip -selection c && tar -zcvf "$1.tar.gz" "$1" && echo "$PASS" && mcrypt "$1.tar.gz" && echo "$1.tar.gz $PASS" | xclip -selection c;  unset -f f; }; f'
alias decrypt='mdecrypt'
alias get-badchars='echo -e "\x22\x27<?>][]{}_)(*;/\x5c"'
alias get-bytes-hex='python3 -c "for i in range(0,256): print(hex(i))"'
alias get-bytes-raw='python3 -c "for i in range(0,256): print(chr(i))"'
alias nonullbyte='sed "s/\x00//g"'
alias urlencode='python3 -c "import sys, urllib as ul; \
    print ul.quote_plus(sys.argv[1])"'
alias urldecode='python3 -c "import sys, urllib as ul; \
    print ul.unquote_plus(sys.argv[1])"'

# Sysadmin
alias aptitall='sudo apt update && sudo apt upgrade -y && sudo apt autoremove -y && sudo apt clean -y && sudo apt purge -y'
alias dpkgi='sudo dpkg -i'
alias tmux-bg='f(){ tmux new-window -d zsh -c "echo $@; $@; zsh";  unset -f f; }; f'
alias tmux-split='f(){ tmux split-window -d zsh -c "echo $@; $@; zsh";  unset -f f; }; f'
alias pserv='python3 -m http.server'

# Recon
alias get-pass-info='f(){ xdg-open "https://cirt.net/passwords?criteria=$@" ;  unset -f f; }; f'
alias recon-virustotal='f(){ xdg-open "https://www.virustotal.com/gui/domain/$1" ;  unset -f f; }; f'
alias recon-crtsh='f(){ curl -sk "https://crt.sh/json?q=$1" | jq . ; unset -f f; }; f'
alias recon-wayback='f(){ curl -sk "https://web.archive.org/cdx/search/cdx?fl=original&collapse=urlkey&url=*.$1" ; unset -f f; }; f'

# Docker Utils
alias dockit='docker run --rm -it -v /tmp:/tmp -v "$PWD":/uhost -w /uhost'
alias dex='docker exec -it $(docker ps | grep -vF "CONTAINER ID" | fzf | cut -d" " -f1)'
alias dexr='docker exec -it -u root $(docker ps | grep -vF "CONTAINER ID" | fzf | cut -d" " -f1)'
alias dockns='sudo nsenter -a -t $(docker inspect -f "{{.State.Pid}}" $(docker ps | grep -vF "CONTAINER ID" | fzf | cut -d" " -f1))'
alias dnorestart='docker update --restart=no $(docker ps -q)'
alias dstopall='docker stop $(docker ps -q)'
alias dkillall='dnorestart && dstopall'
alias dps='docker ps'
alias dwipe-all='docker system prune -a -f --volumes'
alias dwipe-image='docker rmi -f $(docker images -q)'
alias dwipe-network='docker network rm $(docker network ls -q | tr "\n" " ")'
alias dwipe-process='docker rm $(docker ps -a -q)'
alias dwipe-volume='docker volume rm $(docker volume ls -q | tr "\n" " ")'
alias di='docker inspect $(docker ps | grep -vF "NAMES" | fzf | cut -d" " -f1) | jq'
alias dip='docker inspect $(docker ps | grep -vF "NAMES" | fzf | cut -d" " -f1) | jq -r ".[0].NetworkSettings.IPAddress"'

# Docker Tooling
## Hash cracking
alias john='dockit phocean/john_the_ripper_jumbo'
alias hashcat='dockit -w /host dizcza/docker-hashcat:intel-cpu hashcat'

## Sysadmin
alias dsysdig='dockit --privileged -v /var/run/docker.sock:/host/var/run/docker.sock -v /dev:/host/dev -v /proc:/host/proc:ro -v /boot:/host/boot:ro -v /src:/src -v /lib/modules:/host/lib/modules:ro -v /usr:/host/usr:ro -v /etc:/host/etc:ro --entrypoint /usr/bin/sysdig docker.io/sysdig/sysdig --modern-bpf --unbuffer'
alias dcarbonyl='dockit fathyb/carbonyl' # Chrome in Terminal

# Volatility
wvol() { echo "/bind"$(printf "%q" "$(realpath ""$1"")"); }
alias vol3d="sudo docker run --rm -v vol3-cache:/root/.cache/volatility3/ -v /:/bind/ vol3_dck python3 $(wvol ~/vol3/volatility3/vol.py)"
alias volshell3d="sudo docker run --rm -it -v vol3-cache:/root/.cache/volatility3/ -v /:/bind/ vol3_dck python3 $(wvol ~/vol3/volatility3/volshell.py)"
