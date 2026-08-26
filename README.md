# NoAnyLocationCheck
## 一個由 MTF 藥娘發瘋開發的防送中腳本（基本款）

一鍵腳本：
`rm -f /tmp/gpsblock.sh && curl -fsSL "https://raw.githubusercontent.com/edmond1294/NoAnyLocationCheck/main/gpsblock.sh?t=$(date +%s%N)" -o /tmp/gpsblock.sh && chmod +x /tmp/gpsblock.sh && bash /tmp/gpsblock.sh`

### 原理：擋了些定位服務的API，使Google定位等服務無法正常運作。
### 受夠IP送中了
