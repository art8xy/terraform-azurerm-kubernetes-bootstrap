#!/bin/sh
set -eu

req() {
    command -v "${1}" >/dev/null 2>&1 || {
        echo "${1} is not installed. Please install ${1} and try again." >&2
        exit 1
    }
}

req "zip"
req "tar"
req "curl"
req "pip3"
req "python3"

helm_os="linux"
helm_arch="amd64"
helm_version=$(curl -fsSL https://api.github.com/repos/helm/helm/releases/latest | grep '"tag_name"' | cut -d '"' -f4)

python_version="3.14"
python_platform="manylinux2014_x86_64"
python_abi=$(printf '%s' "${python_version}" | tr -d '.')

source="$(pwd)/source"
build="$(pwd)/.build"
zip="$(pwd)/bootstrap.zip"

rm -rf "${build}"
mkdir -p "${build}/bin"
cp -R "${source}"/*.py "${build}/"
cp "${source}/host.json" "${build}/"
mv "${build}/main.py" "${build}/function_app.py"

pip3 install -r "${source}/requirements.txt" \
    --python-version "${python_version}" \
    --platform "${python_platform}" \
    --implementation cp \
    --abi "cp${python_abi}" \
    --only-binary=:all: \
    --target "${build}" > /dev/null

curl -fsSL "https://get.helm.sh/helm-${helm_version}-${helm_os}-${helm_arch}.tar.gz" -o "${build}/helm.tar.gz"
tar -xzf "${build}/helm.tar.gz" -C "${build}"
mv "${build}/${helm_os}-${helm_arch}/helm" "${build}/bin/helm"
chmod +x "${build}/bin/helm"
rm -rf "${build}/helm.tar.gz" "${build}/${helm_os}-${helm_arch}"

cd "${build}"
zip -qr "${zip}" .
