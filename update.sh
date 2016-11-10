#!/bin/bash
set -eo pipefail

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

versions=( "$@" )
if [ ${#versions[@]} -eq 0 ]; then
	versions=( */ )
fi
versions=( "${versions[@]%/}" )

travisEnv=
for version in "${versions[@]}"; do
	packagesBase="http://repo.postgrespro.ru/pgpro-$version/debian/dists/jessie"
	mainList="$(curl -fsSL "$packagesBase/main/binary-amd64/Packages.gz" | gunzip)"
	versionList="$(echo "$mainList"; curl -fsSL "$packagesBase/main/binary-amd64/Packages.gz" | gunzip)"
	fullVersion="$(echo "$versionList" | awk -F ': ' '$1 == "Package" { pkg = $2 } $1 == "Version" && pkg == "postgrespro-'"$version"'" { print $2; exit }' || true)"
	repoKey="GPG-KEY-POSTGRESPRO"
	(
		set -x
		cp docker-entrypoint.sh "$version/"
		if [ $version == "9.5" ]; then
			repoKey="$repoKey-95"
		fi
		sed 's/%%PG_MAJOR%%/'"$version"'/g; s/%%PG_VERSION%%/'"$fullVersion"'/g; s/%%PG_REPO_KEY%%/'"$repoKey"'/g' Dockerfile.template > "$version/Dockerfile"

	)
	
	travisEnv='\n  - VERSION='"$version$travisEnv"
done

travis="$(awk -v 'RS=\n\n' '$1 == "env:" { $0 = "env:'"$travisEnv"'" } { printf "%s%s", $0, RS }' .travis.yml)"
echo "$travis" > .travis.yml
