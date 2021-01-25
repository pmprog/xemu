#!/bin/bash
# This file has been originally downloaded from https://github.com/DiscordHooks/travis-ci-discord-webhook
# Copyright: (C) 2017 Sankarsan Kampa, according to the MIT license: https://github.com/DiscordHooks/travis-ci-discord-webhook/blob/master/LICENSE
# Also, this file has been modified by me for fitting to my needs in the Xemu project: (C)2021 Gabor Lenart (aka LGB)

BOT_NAME="XEMU Builder"
BOT_NAME_FUNNY="XEMU (body-)Builder"
#BOT_AVATAR="https://travis-ci.org/images/logos/TravisCI-Mascot-1.png"
BOT_AVATAR="https://lgblgblgb.github.io/xemu/images/xemu-48x48.png"

case $1 in
	"building" )
		EMBED_COLOR=15105570
		STATUS_MESSAGE="Building"
		AVATAR="https://travis-ci.org/images/logos/TravisCI-Mascot-red.png"
		;;

	"success" )
		EMBED_COLOR=3066993
		STATUS_MESSAGE="Passed"
		AVATAR="https://travis-ci.org/images/logos/TravisCI-Mascot-blue.png"
		;;

	"failure" )
		EMBED_COLOR=15158332
		STATUS_MESSAGE="Failed"
		AVATAR="https://travis-ci.org/images/logos/TravisCI-Mascot-red.png"
		;;

	* )
		EMBED_COLOR=0
		STATUS_MESSAGE="Status Unknown"
		AVATAR="https://travis-ci.org/images/logos/TravisCI-Mascot-1.png"
		;;
esac

shift

if [ $# -lt 1 ]; then
	echo "[DISCORD] ERROR: Missing second parameter: build architecture" >&2
	exit 1
fi
BUILD_ARCH="$1"

shift

if [ $# -lt 1 ]; then
	echo "[DISCORD] ERROR: Missing list of brances" >&2
	exit 1
fi
echo "[DISCORD] Notification for ${BUILD_ARCH} with allowed notification list for branches: ${1}"
NOTIFY_BRANCHES="${1}"

shift

if [ $# -lt 1 ]; then
	echo "[DISCORD] ERROR: Missing webhook URL(s)" >&2
	exit 1
fi



# ---------------------------------------------------------------------------------------------
# Assume, this script is used on Travis
# Use GITHUB workflows to get information instead, if available
if [ "$TRAVIS_BRANCH" == "" -a "$GITHUB_REF" != "" ]; then
	TRAVIS_BRANCH="$(echo $GITHUB_REF | awk -F/ '{ print $NF }')"
fi
# If either of those, try to use local parameters
if [ "$TRAVIS_COMMIT" == "" ]; then
	TRAVIS_COMMIT="$(git log -1 --pretty="%H")"
fi
if [ "$TRAVIS_BRANCH" == "" ]; then
	TRAVIS_BRANCH="$(git branch | awk 'BEGIN { s = "UNKNOWN" } $1 == "*" { s = $2 } END { print s }')"
fi
if [ "$TRAVIS_PULL_REQUEST" == "" ]; then
	TRAVIS_PULL_REQUEST="false"
fi
if [ "$TRAVIS_REPO_SLUG" == "" ]; then
	# Ehmm, kind of lame ...
	TRAVIS_REPO_SLUG="$(git config --get remote.origin.url | egrep -o '[^/]+/[^/]+$' | sed 's/\.git$//')"
fi
#if [ "$TRAVIS_BUILD_WEB_URL" == "" ]; then
#	TRAVIS_BUILD_WEB_URL="https://lgblgblgb.github.io/xemu/"
#fi
# ---------------------------------------------------------------------------------------------
cd `dirname $0`/../..
XEMU_VERSION="$(cat build/objs/cdate.data)"
if [ "$XEMU_VERSION" = "" ]; then
	XEMU_VERSION="UNKNOWN"
fi
XEMU_VERSION="$XEMU_VERSION/$TRAVIS_BRANCH"
# ---------------------------------------------------------------------------------------------
if ! echo ",$NOTIFY_BRANCHES," | grep -q ",$TRAVIS_BRANCH," ; then
	echo "[DISCORD] REJECT: This branch (${TRAVIS_BRANCH}) was not in the configured branches to notify. Allowed branches: ${NOTIFY_BRANCHES}"
	exit 0
fi
# ---------------------------------------------------------------------------------------------
# End of madness


AUTHOR_NAME="$(git log -1 "$TRAVIS_COMMIT" --pretty="%aN")"
COMMITTER_NAME="$(git log -1 "$TRAVIS_COMMIT" --pretty="%cN")"
COMMIT_SUBJECT="$(git log -1 "$TRAVIS_COMMIT" --pretty="%s")"
COMMIT_MESSAGE="$(git log -1 "$TRAVIS_COMMIT" --pretty="%b")" | sed -E ':a;N;$!ba;s/\r{0,1}\n/\\n/g'

if [ ${#COMMIT_SUBJECT} -gt 256 ]; then
	COMMIT_SUBJECT="$(echo "$COMMIT_SUBJECT" | cut -c 1-253)"
	COMMIT_SUBJECT+="..."
fi

if [ -n $COMMIT_MESSAGE ] && [ ${#COMMIT_MESSAGE} -gt 1900 ]; then
	COMMIT_MESSAGE="$(echo "$COMMIT_MESSAGE" | cut -c 1-1900)"
	COMMIT_MESSAGE+="..."
fi

if [ "$AUTHOR_NAME" == "$COMMITTER_NAME" ]; then
	CREDITS="$AUTHOR_NAME authored & committed"
else
	CREDITS="$AUTHOR_NAME authored & $COMMITTER_NAME committed"
fi

if [ "$TRAVIS_PULL_REQUEST" != "false" ]; then
	URL="https://github.com/$TRAVIS_REPO_SLUG/pull/$TRAVIS_PULL_REQUEST"
	echo "[DISCORD] No webhook activation for pull requests currently" >&2
	exit 0
else
	URL=""
fi


TIMESTAMP=$(date -u +%FT%TZ)


MSG=":desktop:  New Xemu build version **${XEMU_VERSION}** for **${BUILD_ARCH}** is now ***[on-line](<https://lgblgblgb.github.io/xemu/>)!***"
# Branch based decisions
MSG="${MSG} :scientist: "
if [ "$TRAVIS_BRANCH" == "master" ]; then
	MSG="${MSG}This is kind-of-**stable** (branch: **${TRAVIS_BRANCH}**) build, intended for _general use_."
elif [ "$TRAVIS_BRANCH" == "next" ]; then
	MSG="${MSG}This is next/**to-be-stable** with possible problems (branch: **${TRAVIS_BRANCH}**) build, so _you have been warned_, but you're more than welcome if you want to _help testing Xemu by using this branch_."
elif [ "$TRAVIS_BRANCH" == "dev" ]; then
	MSG="${MSG}This is **development** (branch: **${TRAVIS_BRANCH}**) build, ~~it may overclock your robot vacuum cleaner~~, or _whatever_."
else
	MSG="${MSG}This is **secret** (branch: **${TRAVIS_BRANCH}**) build, ~~you don't want to even know about~~ ... errr ... _you want to be **extremely** careful with_."
fi 
# Details about the build
MSG="$MSG :zap: See git commit [**\`${TRAVIS_COMMIT:0:7}\`**](<https://github.com/${TRAVIS_REPO_SLUG}/commit/${TRAVIS_COMMIT}>)"
if [ "$TRAVIS_JOB_WEB_URL" != "" ]; then
	MSG="$MSG and the [build log](<${TRAVIS_JOB_WEB_URL}>)"
fi
MSG="${MSG}. :calendar: _${BOT_NAME_FUNNY} @ ${TIMESTAMP}_"


WEBHOOK_DATA='{
	"username": "'$BOT_NAME'",
	"avatar_url": "'$BOT_AVATAR'",
	"content": "'$MSG'"
}'

#exit 0

for ARG in "$@"; do
	echo -e "[DISCORD] Sending webhook to Discord ... "

	(curl --fail --progress-bar -A "TravisCI-Webhook" -H Content-Type:application/json -H X-Author:Xemu -d "${WEBHOOK_DATA//	/ }" "$ARG" \
	&& echo -e "[DISCORD] Successfully sent the webhook :-)") || echo -e "[DISCORD] Unable to send webhook :-("
done

exit 0
