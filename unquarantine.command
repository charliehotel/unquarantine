#!/bin/zsh

export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:/usr/local/bin"

APP_DIR="/Applications"
LIMIT=50

clear

echo "🔓 macOS 앱 격리 해제기"
echo
echo "최근 생성/복사/수정된 앱을 기준으로 /Applications 폴더의 앱을 불러오는 중입니다..."
echo

has_quarantine() {
  [[ -n "$(/usr/bin/find "$1" -xattrname com.apple.quarantine -print -quit 2>/dev/null)" ]]
}

sort_keys=()
app_names=()
app_paths=()
app_dates=()
app_quarantines=()
app_index=0

while IFS= read -r -d '' app; do
  (( app_index++ ))

  birth=$(/usr/bin/stat -f "%B" "$app")
  modified=$(/usr/bin/stat -f "%m" "$app")
  changed=$(/usr/bin/stat -f "%c" "$app")

  latest=$birth
  [[ $modified -gt $latest ]] && latest=$modified
  [[ $changed -gt $latest ]] && latest=$changed

  date_text=$(/bin/date -r "$latest" "+%Y-%m-%d %H:%M:%S")
  name=$(/usr/bin/basename "$app")

  if /usr/bin/xattr -p com.apple.quarantine "$app" >/dev/null 2>&1; then
    quarantine="격리됨"
  else
    quarantine="격리 없음"
  fi

  sort_keys+=("$latest $app_index")
  app_names[$app_index]="$name"
  app_paths[$app_index]="$app"
  app_dates[$app_index]="$date_text"
  app_quarantines[$app_index]="$quarantine"
done < <(/usr/bin/find "$APP_DIR" -maxdepth 1 -type d -name "*.app" -print0)

if [[ ${#sort_keys[@]} -eq 0 ]]; then
  /usr/bin/osascript -e 'display dialog "Applications 폴더에서 앱을 찾지 못했습니다." buttons {"확인"} default button "확인" with icon caution'
  exit 1
fi

sorted=("${(@f)$(printf "%s\n" "${sort_keys[@]}" | /usr/bin/sort -rn -k1,1 | /usr/bin/head -n "$LIMIT")}")

display_items=()

for sort_key in "${sorted[@]}"; do
  index="${sort_key[(w)2]}"
  date_text="${app_dates[$index]}"
  quarantine="${app_quarantines[$index]}"
  name="${app_names[$index]}"

  display_items+=("[$index] $name    |    $date_text    |    $quarantine")
done

selected=$(
/usr/bin/osascript - "${display_items[@]}" <<'APPLESCRIPT'
on run argv
  set chosenApp to choose from list argv with title "macOS 앱 격리 해제기" with prompt "격리 해제할 앱을 선택하세요. 최근 생성/복사/수정된 앱이 위쪽에 표시됩니다." OK button name "선택" cancel button name "취소"
  if chosenApp is false then
    return ""
  else
    return item 1 of chosenApp
  end if
end run
APPLESCRIPT
)

if [[ -z "$selected" ]]; then
  echo "취소했습니다."
  exit 0
fi

selected_index="${selected#\[}"
selected_index="${selected_index%%\]*}"

if ! [[ "$selected_index" == <-> ]] || [[ -z "${app_paths[$selected_index]}" ]]; then
  /usr/bin/osascript -e 'display dialog "선택한 앱을 확인할 수 없습니다." buttons {"확인"} default button "확인" with icon stop'
  exit 1
fi

app_path="${app_paths[$selected_index]}"
app_name="${app_names[$selected_index]}"

if ! has_quarantine "$app_path"; then
  /usr/bin/osascript - "$app_name" "$app_path" <<'APPLESCRIPT'
on run argv
  set appName to item 1 of argv
  set appPath to item 2 of argv
  display dialog "선택한 앱에는 quarantine 속성이 없습니다." & linefeed & linefeed & "앱: " & appName & linefeed & "경로: " & appPath buttons {"확인"} default button "확인" with icon note
end run
APPLESCRIPT
  echo "선택한 앱에는 quarantine 속성이 없습니다: $app_name"
  exit 0
fi

confirm=$(
/usr/bin/osascript - "$app_name" "$app_path" <<'APPLESCRIPT'
on run argv
  set appName to item 1 of argv
  set appPath to item 2 of argv
  display dialog "선택한 앱의 quarantine 속성을 제거합니다." & linefeed & linefeed & "앱: " & appName & linefeed & "경로: " & appPath & linefeed & linefeed & "신뢰할 수 있는 출처의 앱에만 사용하세요." buttons {"취소", "격리 해제"} default button "격리 해제" cancel button "취소" with icon caution
  return button returned of result
end run
APPLESCRIPT
)

if [[ "$confirm" != "격리 해제" ]]; then
  echo "취소했습니다."
  exit 0
fi

echo
echo "선택한 앱: $app_name"
echo "경로: $app_path"
echo
echo "sudo 암호를 입력하면 격리 해제를 실행합니다."
echo

/usr/bin/sudo /usr/bin/xattr -rd com.apple.quarantine "$app_path"

if [[ $? -eq 0 ]]; then
  echo
  echo "✅ 완료: $app_name"

  /usr/bin/osascript - "$app_name" <<'APPLESCRIPT'
on run argv
  set appName to item 1 of argv
  display dialog "격리 해제가 완료되었습니다." & linefeed & linefeed & appName buttons {"확인"} default button "확인" with icon note
end run
APPLESCRIPT
else
  echo
  echo "❌ 실패했습니다."
  /usr/bin/osascript -e 'display dialog "격리 해제에 실패했습니다. 터미널 메시지를 확인하세요." buttons {"확인"} default button "확인" with icon stop'
fi

echo
read -k 1 "?아무 키나 누르면 종료됩니다..."
