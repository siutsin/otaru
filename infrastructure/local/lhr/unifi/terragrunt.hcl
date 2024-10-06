include {
  path = find_in_parent_folders()
}

terraform {
  source = "${get_parent_terragrunt_dir()}//modules/unifi"
}

inputs = {
  device_gateway = {
    gateway00 = {
      name = "Cloud Gateway Ultra"
    }
  }
  device_switch = {
    switch00 = {
      name = "USW Lite 8 PoE"
    }
  }
  device_wifi = {
    wifi00 = {
      name = "U7 Pro"
    }
  }
}
