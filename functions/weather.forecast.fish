function weather.forecast -d "Displays weather forecast lines"
  set -l api_key (config weather --get api-key)

  if not set json (weather.fetch "https://api.open-meteo.com/v1/forecast" \
        hourly=temperature_2m,precipitation \
        latitude=$argv[1] longitude=$argv[2] temperature_unit=celsius)
    echo "Unable to fetch weather data; please try again later."
    return 1
  end

  set count (echo $json | jq '.hourly.time | length')
  for index in (seq 1 3 $count)
    set day (echo $json | jq --raw-output '.hourly.time['$index'] | strptime("%Y-%m-%dT%H:%M") | strftime("%m/%d")')
    contains $day $days
      or set days $days $day

    set temp $temp (echo $json | jq -r ".hourly.temperature_2m[$index]")
    set rain $rain (echo $json | jq -r ".hourly.precipitation[$index]")
  end

  printf "  Temperature: %s\n" (spark $temp)
  printf "               %s\n\n" (__print_days_strip $days)

  printf "Precipitation: %s\n" (spark $rain)
  printf "               %s\n" (__print_days_strip $days)
end

function __print_days_strip
  for day in $argv
    printf "%s   " $day
  end
end
