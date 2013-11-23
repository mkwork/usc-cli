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
    echo $UCS_CURRENT_PLAYER > $UCS_CURRENT_PLAYER_FILE
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
    echo $UCS_CURRENT_PLAYER > $UCS_CURRENT_PLAYER_FILE
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
    notify-send "Players:" "$players" $icon -t 1
}

function get-current-track-description {
    gdbus call --session --dest com.canonical.indicator.sound --object-path \
 /com/canonical/indicator/sound --method org.gtk.Actions.Describe $1 
 }

function replace-html-escapes {
    echo "'"$1"'" | perl -MHTML::Entities -le \
    'while(<>) {print decode_entities($_);}' \
    | sed -e "s/^'//" -e "s/'$//"

}

function parse-description {
    description_part_regexp="'$2': <'.*?'>"
    echo "$1" | grep -oP "$description_part_regexp" \
        | grep -oP "<'.*'>" | sed -e "s/^<'//" -e "s/'>$//"
}

function show-current-track {
    description=`get-current-track-description $UCS_CURRENT_PLAYER`
    echo $description

    state=`parse-description "$description" state`
    title=`replace-html-escapes "$(parse-description "$description" title)"`
    artist=`replace-html-escapes "$(parse-description "$description" artist)"`
    album=`replace-html-escapes "$(parse-description "$description" album)"`
    art_url=`parse-description "$description" art-url`

    echo "Title: $title"
    echo "Artist: $artist"
    echo "Album: $album"
    echo "Art url: $art_url"

    art_url_local_path=$(echo "$art_url" | perl -MURI::URL -le 'while(<>){$url=new URI::URL "$_";print $url->local_path}')
    if [ -f "$art_url_local_path" ];
    then
        notify_icon=$art_url_local_path
    else
        notify_icon=$(current-player-icon)
    fi

    if [ -z "$title" ];
    then
        notify_tittle="Now $(echo $state | tr [:upper:] [:lower:]):"
    else
        notify_tittle="$title"
    fi

    if [ ! -z "$album" ];
    then
        notify_body="$album\n"
    fi

    if [ ! -z "$artist" ];
    then
        notify_body="$artist\n"
    fi

    notify-send "$notify_tittle" "$notify_body" -i "$notify_icon" -t 1200
}

function show-usage {
    echo ' This script was introduced to manipulate on ubuntus unity component 
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
 show-track - shows currently playing track information
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
        ;;
    previous-player)
        player-previous
        ;;
    show)
        show-current-player
        ;;
    show-track)
        show-current-track
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
