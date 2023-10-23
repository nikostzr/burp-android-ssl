#!/bin/bash
echo "Installing Burp certificate"
curl http://burp/cert -x localhost:8080 > /tmp/cacert.der
openssl x509 -inform DER -in /tmp/cacert.der -out /tmp/cacert.pem
HASH=$(openssl x509 -inform PEM -subject_hash_old -in /tmp/cacert.pem | head -1)
echo "The certificate hash is" $HASH
mv /tmp/cacert.pem /tmp/$HASH.0
adb push /tmp/$HASH.0 /data/local/tmp
adb shell su -c "mount -o rw,remount /system; mv /data/local/tmp/*.0 /system/etc/security/cacerts" 
if [ $? -eq 0 ]; then
    echo "Burp certificate installed"
else
    rm -fdr ./MMT-Extended
    echo "Mounting /system failed. Trying alternative method"
    git clone https://github.com/Zackptg5/MMT-Extended
    cd MMT-Extended
    mkdir -p ./system/etc/security
    rm -rf ./zygisk
    rm ./system/placeholder
    cd ./system/etc/security
    adb pull /system/etc/security/cacerts/ .
    cp /tmp/$HASH.0 ./cacerts/
    cd ../../..
    sed '/REPLACE="/{n;s/$/\n\nset_perm_recursive \$MODPATH\/system\/etc\/security\/cacerts 0 0 0755 0644/;}' customize.sh > output.txt
    sed 's/REPLACE="/ &\n\/system\/etc\/security\/cacerts/'  output.txt > customize.sh
   
    chmod +x customize.sh
    zip -9 -r MMT.zip .
    adb push MMT.zip /storage/self/primary/Download/
    echo "Proceed with Magisk and zygisk to finish the process"
fi
fingerprint=$(openssl x509 -in /tmp/cacert.der -inform DER -pubkey -noout | openssl pkey -pubin -outform der | openssl dgst -sha256 -binary | openssl enc -base64 | tr -d '\n')
echo "chrome --ignore-certificate-errors-spki-list=$fingerprint" > finger.txt

# List of file paths
file_paths=(
  "/data/local/chrome-command-line"
  "/data/local/android-webview-command-line"
  "/data/local/webview-command-line"
  "/data/local/content-shell-command-line"
  "/data/local/tmp/chrome-command-line"
  "/data/local/tmp/android-webview-command-line"
  "/data/local/tmp/webview-command-line"
  "/data/local/tmp/content-shell-command-line"
)
adb push finger.txt /data/local/tmp
for file_path in "${file_paths[@]}"; do
  echo "Processing file: $file_path"
  adb shell su -c "cp /data/local/tmp/finger.txt $file_path"
  adb shell su -c "chmod 555 $file_path"
done

adb shell am force-stop com.android.chrome


