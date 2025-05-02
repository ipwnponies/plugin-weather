function weather -d "Displays weather info"
  set -l api_key (config weather --get api-key)

  # Check external dependent programs.
  if not type -q jq
    echo "The jq program is required to parse weather data."
    echo "See https://stedolan.github.io/jq for details."
    return 1
  else
    set -l jq_version (jq --version 2>&1 | tr -dC '[:digit:].')
    if test "$jq_version" -lt 1.5 2> /dev/null
      echo "jq version $jq_version detected"
      echo "You must have jq version 1.5 or newer installed to parse weather data."
      echo "You can download the latest version of jq from https://stedolan.github.io/jq."
      return 1
    end
  end

  # Display help message.
  if begin; contains -- -h $argv; or contains -- --help $argv; end
    weather.help
    return 0
  end

  # Determine the location to use.
  set loc (config weather --get location)
  if test (count $argv) -ne 0
    set loc $argv
  end
  if test -z $loc
    set location (weather.location)

    # Fetch weather data based on the location.
    if not set json (weather.fetch "https://api.open-meteo.com/v1/forecast" \
        current=temperature_2m,relative_humidity_2m,weather_code,surface_pressure,wind_speed_10m,wind_gusts_10m,wind_direction_10m \
        latitude=$location[1] longitude=$location[2] temperature_unit=celsius)
      echo "Unable to fetch weather data; please try again later."
      return 1
    end
  else
    # Fetch weather based on a search query.
    if not set json (weather.fetch "http://api.openweathermap.org/data/2.5/weather" "q=$loc" APPID=$api_key)
      echo "Unable to fetch weather data; please try again later."
      return 1
    end

    set location (echo $json | jq -r '.coord.lat, .coord.lon, .name, .sys.country')
  end

  printf "Weather for $location[3], $location[4]\n\n"

  set temp (echo $json | jq '.current.temperature_2m')
  set wind_speed (echo $json | jq '.current.wind_speed_10m')
  set wind_gust (echo $json | jq '.current.wind_gusts_10m')
  set wind_deg (echo $json | jq '.current.wind_direction_10m')

  # convert m/s to km/h
  set wind_speed_kmh ( math -s 1 $wind_speed \* 3.6 )
  if test -n "$wind_gust" -a "$wind_gust" != "null"
    set wind_gust_kmh ( math -s 1 $wind_gust \* 3.6 )
  end

  # If we want miles per hour
  #set wind_speed_mph ( math -s 1 $wind_speed \* 2.23694 )

  # Get the cardinal direction from the heading
  set directions N NE E SE S SW W NW N
  if test (echo $version | cut -d. -f1) -lt 3
    set wind_deg_octant (math -s 0 "(($wind_deg % 360) / 45) + 1")
  else
    set wind_deg_octant (math "round(($wind_deg % 360) / 45) + 1")
  end
  set wind_dir $directions[$wind_deg_octant]

  # Display forecast summary
  echo "Temperature: "(__weather_print_temperature $temp)
  echo "   Humidity: "(echo $json | jq '.current.relative_humidity_2m')"%"
  echo " Cloudiness: "(__weather_code (echo $json | jq '.current.weather_code'))
  echo "   Pressure: "(echo $json | jq '.current.surface_pressure')" hPa"
  echo -n "       Wind: from $wind_dir ($wind_deg°) at $wind_speed m/s ($wind_speed_kmh km/h)"
  if not test $wind_gust = null
    echo " gusting to $wind_gust m/s ($wind_gust_kmh km/h)"
  else
    echo
  end

  printf "\n5-day forecast\n"
  weather.forecast $location
end


# Prints the given temperature to the console.
#
# Arguments:
#   1: The temperature to display in Kelvin.
function __weather_print_temperature
  set celsius $argv[1]

  set -l temperature_units (config weather --get temperature-units)

  set kelvin (math "$celsius + 273.15")

  if test "$temperature_units" = "kelvin"
    echo "$kelvin K"
    return 0
  end

  if test $temperature_units = "celsius"
    echo "$celsius °C"
    return 0
  end

  set fahrenheit (math "$celsius * 1.8 + 32")

  if test $temperature_units = "fahrenheit"
    echo "$fahrenheit °F"
  else
    echo "$celsius °C ($fahrenheit °F)"
  end
end

function __weather_code
    set code $argv[1]

    switch $code
        case 0
            echo "Clear sky"
        case 1 2 3
            echo "Mainly clear, partly cloudy, and overcast"
        case 45 48
            echo "Fog and depositing rime fog"
        case 51 53 55
            echo "Drizzle: Light, moderate, and dense intensity"
        case 56 57
            echo "Freezing Drizzle: Light and dense intensity"
        case 61 63 65
            echo "Rain: Slight, moderate, and heavy intensity"
        case 66 67
            echo "Freezing Rain: Light and heavy intensity"
        case 71 73 75
            echo "Snow fall: Slight, moderate, and heavy intensity"
        case 77
            echo "Snow grains"
        case 80 81 82
            echo "Rain showers: Slight, moderate, and violent"
        case 85 86
            echo "Snow showers: Slight and heavy"
        case 95
            echo "Thunderstorm: Slight or moderate"
        case 96 99
            echo "Thunderstorm with slight and heavy hail"
        case '*'
            echo "Unknown weather code"
    end
end
