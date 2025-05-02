function weather.location -d "Get the current geographic location"
  # Fetch location data based on our IP
  if not set geoip_data (weather.fetch "https://freeip2geo.net/api")
    echo "Unable to query GeoIP data; please try again later."
    return 1
  end

  # Echo coordiantes.
  echo $geoip_data | jq '.latitude'
  echo $geoip_data | jq '.longitude'
  echo $geoip_data | jq -r '.city?'
  echo $geoip_data | jq -r '.country_name'
end
