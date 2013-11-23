#!/bin/bash

# This script was introduced to manipulate ubuntus unity component known as 
# com.canonical.indicator.sound 
#----------------------------------------------------------------------------
# Usage:
# unity-control-sound <command>
# available commands:
# play - togles play/pause for current player
# next - switch next track in current player
# previous - switch previous track in current player
# next-player - switch current player to next
# previous-player - switch current player to previous
# show - shows current player 
# help - show help

UCS_CACHE=~/.cache/unity-control-sound
UCS_CURRENT_PLAYER_FILE=$UCS_CACHE/current-player
UCS_SYSTEM_WIDE_LAUNCHERS_PATH=/usr/share/applications
UCS_LAUNCHERS_PATH=~/.local/share/applications
UCS_INTERESTED_PLAYERS=`dconf read \
    /com/canonical/indicator/sound/interested-media-players \
    | sed  -e"s:[],'\[]::g" `
UCS_PREFFERED_PLAYERS=`dconf read /com/canonical/indicator/sound/preferred-media-players \
    | sed  -e "s:[],'\[]::g"`

mkdir -p $UCS_CACHE
touch $UCS_CURRENT_PLAYER_FILE
UCS_CURRENT_PLAYER=`cat $UCS_CURRENT_PLAYER_FILE`

function initialize-current-player {
    #if current player is not a player which can be used set it for right
    if ! echo $UCS_INTERESTED_PLAYERS | grep -q $UCS_CURRENT_PLAYER ;
    then
        UCS_CURRENT_PLAYER=`echo $UCS_PREFFERED_PLAYERS | grep -o "^\S*[^.]"`
        UCS_CURRENT_PLAYER=`echo $UCS_CURRENT_PLAYER | sed "s/\s//g"`
        echo Current player now is '"'$UCS_CURRENT_PLAYER'"'
    fi
}

function player-next {
    initial_player=$UCS_CURRENT_PLAYER
    for player in $UCS_INTERESTED_PLAYERS 
    do
        if [ -z "$first_player" ];
        then
            first_player=$player
        fi

        if [ "$previous_player" == "$UCS_CURRENT_PLAYER" ];
        then
            UCS_CURRENT_PLAYER=$player
            break
        fi
        previous_player=$player
    done
    if [ "$initial_player" == "$UCS_CURRENT_PLAYER" ];
    then
        UCS_CURRENT_PLAYER=$first_player
    fi
}


function player-previous {
    initial_player=$UCS_CURRENT_PLAYER
    for player in $UCS_INTERESTED_PLAYERS 
    do
        if [ -z "$first_player" ];
        then
            first_player=$player
        fi

        if [ "$player" == "$UCS_CURRENT_PLAYER" ];
        then
            UCS_CURRENT_PLAYER=$previous_player
        fi
        previous_player=$player
    done
    if [ -z "$UCS_CURRENT_PLAYER" ];
    then
        UCS_CURRENT_PLAYER=$previous_player
    fi
}

function player-action {
    action="'"$1.$UCS_CURRENT_PLAYER"'"
    echo $action
    gdbus call --session --dest com.canonical.indicator.sound --object-path \
        /com/canonical/indicator/sound --method org.gtk.Actions.Activate \
       $action [] {}
}

function player-launcher {
    name=$1
    launcher=$UCS_LAUNCHERS_PATH/$name 
    system_wide_launcher=$UCS_SYSTEM_WIDE_LAUNCHERS_PATH/$name

    if [ -f "$launcher" ];
    then
        echo $launcher 
    else
        echo $system_wide_launcher 
    fi
}

function player-display-name {
    name=$1
    launcher=`player-launcher $name`
    if [ -f "$launcher" ];
    then
        cat $launcher | grep -m 1 "^Name=" \
            | sed "s/Name=//"
    else
        echo $player | sed "s/.desktop//"
    fi

}

function current-player-icon {
    launcher=`player-launcher $UCS_CURRENT_PLAYER`
    if [ -f "$launcher" ];
    then
        cat $launcher | grep "Icon=" \
            | sed "s/Icon=//"
    fi
}

function show-current-player {
    echo Curent player '"'$UCS_CURRENT_PLAYER'"'
    for player in $UCS_INTERESTED_PLAYERS
    do
       if [ $player == $UCS_CURRENT_PLAYER ];
       then
           players=$players*
       fi

       player_name=`player-display-name $player`
       players=$players$player_name\\n
    done
    icon=`current-player-icon`
    if ! [ -z $icon ];
    then
        icon="-i $icon"
    fi

    echo Icon is "$icon"
    notify-send 'Players:' $players -t 1 -u LOW  $icon 
}

function show-usage {
    echo ' This script was introduced to manipulate ubuntus unity component 
 known as com.canonical.indicator.sound 
 ----------------------------------------------------------------------------
 Usage:
 unity-control-sound <command> 
 available commands: 
 play - togles play/pause for current player 
 next - switch next track in current player 
 previous - switch previous track in current player 
 next-player - switch current player to next 
 previous-player - switch current player to previous 
 show - shows current player 
 help - shows this help message'
}

initialize-current-player

case $1 in
    play)
        player-action play
        ;;
    next)
        player-action next
        ;;
    previous)
        player-action previous
        ;;
    next-player)
        player-next
        show-current-player
        ;;
    previous-player)
        player-previous
        show-current-player
        ;;
    show)
        show-current-player
        ;;
    help)
        show-usage
        exit
        ;;
    *)
        show-usage
        exit
        ;;

esac
echo $UCS_CURRENT_PLAYER > $UCS_CURRENT_PLAYER_FILE
