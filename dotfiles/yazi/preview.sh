# ~/.config/yazi/preview.sh

file="$1"
mime=$(file --mime-type -Lb "$file")

case "$mime" in
text/*)
  bat --style=numbers --color=always "$file"
  ;;

application/json)
  jq . "$file" | bat --color=always
  ;;

image/*)
  chafa "$file"
  ;;

video/*)
  ffmpegthumbnailer -i "$file" -o /tmp/thumb.jpg -s 0
  chafa /tmp/thumb.jpg
  ;;

application/pdf)
  pdftotext "$file" - | head -n 100 | bat --color=always
  ;;

application/zip | application/x-tar)
  atool -l "$file"
  ;;

*)
  file "$file"
  ;;
esac
