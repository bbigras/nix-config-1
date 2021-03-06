{ lib, pkgs, ... }:
{
  imports = [
    ../../core
    ../../core/unbound.nix

    ../../hardware/rpi4.nix
    ../../hardware/no-mitigations.nix

    ../../users/bemeurer
  ];

  boot.loader = {
    generic-extlinux-compatible.enable = lib.mkForce false;
    raspberryPi = {
      enable = true;
      firmwareConfig = ''
        dtoverlay=vc4-fkms-v3d
      '';
      version = 4;
    };
  };

  environment.systemPackages = with pkgs; [ raspberrypi-tools ];

  fileSystems = lib.mkForce {
    "/boot" = {
      device = "/dev/disk/by-label/NIXOS_BOOT";
      fsType = "vfat";
    };
    "/" = {
      device = "/dev/disk/by-label/NIXOS_SD";
      fsType = "ext4";
    };
  };

  networking = {
    hostName = "riemann";
    firewall = {
      allowedTCPPorts = [ 5000 ];
      extraCommands = ''
        iptables -t nat -A PREROUTING -p tcp --dport 80 -j REDIRECT --to-port 5000
        iptables -t nat -I OUTPUT -p tcp -d 127.0.0.1 --dport 80 -j REDIRECT --to-ports 5000
      '';
    };
    wireless.iwd.enable = true;
  };

  nix.gc = {
    automatic = true;
    options = "-d";
  };

  systemd.network.networks = {
    lan = {
      DHCP = "yes";
      linkConfig.RequiredForOnline = "no";
      matchConfig.MACAddress = "dc:a6:32:b8:bb:aa";
    };
    wifi = {
      DHCP = "yes";
      matchConfig.MACAddress = "dc:a6:32:b8:bb:ab";
    };
  };

  time.timeZone = "America/Los_Angeles";

  services.octoprint = {
    enable = true;
    plugins = plugins: with plugins; [
      displaylayerprogress
      marlingcodedocumentation
      printtimegenius
      themeify
      octoklipper
      octoprint-dashboard
    ];
    extraConfig = {
      accessControl.enabled = false;
      appearance.name = "Voron 0";
      serial = {
        port = "/run/klipper/tty";
        baudrate = "250000";
        autoconnect = true;
        disconnectOnErrors = false;
      };
      onlineCheck = {
        enabled = true;
        host = "1.1.1.1";
      };
    };
  };

  services.klipper = {
    enable = true;
    octoprintIntegration = true;
    settings = {
      mcu.serial = "/dev/serial/by-id/usb-Klipper_stm32f103xe_30FFDD055346323032890543-if00";
      "mcu displayEncoder" = {
        serial = "/dev/serial/by-id/usb-Klipper_stm32f042x6_2A001B0015434E5532373620-if00";
        restart_method = "command";
      };

      display = {
        click_pin = "^!displayEncoder:PA1";
        display_group = "__voron_display";
        encoder_pins = "^displayEncoder:PA4, ^displayEncoder:PA3";
        i2c_bus = "i2c1a";
        i2c_mcu = "displayEncoder";
        kill_pin = "^!displayEncoder:PA5";
        lcd_type = "sh1106";
        vcomh = 31;
        x_offset = 2;
      };

      "neopixel displayStatus" = {
        pin = "displayEncoder:PA0";
        chain_count = 1;
        color_order = "GRB";
        initial_RED = 0;
        initial_GREEN = 0.0298;
        initial_BLUE = 0.02706;
      };

      stepper_x = {
        dir_pin = "PB12";
        enable_pin = "!PB14";
        step_pin = "PB13";

        endstop_pin = "PC0";
        position_endstop = 118;
        position_max = 118.5;

        homing_positive_dir = true;
        homing_retract_dist = 5;
        homing_speed = 70;
        second_homing_speed = 5;
        step_distance = "0.0125";
      };

      "tmc2209 stepper_x" = {
        tx_pin = "PC10";
        uart_address = 0;
        uart_pin = "PC11";

        hold_current = ".90";
        interpolate = true;
        microsteps = 8;
        run_current = ".90";
        sense_resistor = 0.110;
        stealthchop_threshold = 500;
      };

      stepper_y = {
        dir_pin = "PB2";
        enable_pin = "!PB11";
        step_distance = "0.0125";
        step_pin = "PB10";

        endstop_pin = "PC1";
        position_endstop = 120;
        position_max = 120;

        homing_positive_dir = true;
        homing_retract_dist = 5;
        homing_speed = 70;
        second_homing_speed = 5;
      };

      "tmc2209 stepper_y" = {
        tx_pin = "PC10";
        uart_address = 2;
        uart_pin = "PC11";

        hold_current = ".90";
        interpolate = true;
        microsteps = 8;
        run_current = ".90";
        sense_resistor = 0.110;
        stealthchop_threshold = 500;
      };

      stepper_z = {
        dir_pin = "PC5";
        enable_pin = "!PB1";
        step_distance = "0.0025";
        step_pin = "PB0";

        endstop_pin = "PC2";
        position_endstop = "-0.690";
        position_max = 120;
        position_min = -1;

        homing_positive_dir = false;
        homing_retract_dist = 3;
        homing_speed = 10;
        second_homing_speed = 3;
      };

      "tmc2209 stepper_z" = {
        tx_pin = "PC10";
        uart_address = 1;
        uart_pin = "PC11";

        hold_current = ".20";
        interpolate = true;
        microsteps = 8;
        run_current = ".30";
        sense_resistor = 0.110;
        stealthchop_threshold = 500;
      };

      extruder = {
        dir_pin = "PB4";
        enable_pin = "!PD2";
        step_distance = "0.00215282464109938";
        step_pin = "PB3";

        filament_diameter = "1.750";
        nozzle_diameter = "0.400";

        control = "pid";
        heater_pin = "PC8";
        pid_Kd = "95.541";
        pid_Ki = "0.905";
        pid_Kp = "18.597";
        sensor_pin = "PA0";
        sensor_type = "SliceEngineering 450";

        max_extrude_cross_section = ".8";
        max_extrude_only_distance = 780;
        max_temp = 350;
        min_extrude_temp = 220;
        min_temp = 0;
        pressure_advance = "0.300";
        pressure_advance_smooth_time = 0.040;
      };

      "tmc2209 extruder" = {
        tx_pin = "PC10";
        uart_address = 3;
        uart_pin = "PC11";

        hold_current = "0.84";
        interpolate = true;
        microsteps = 16;
        run_current = "0.84";
        sense_resistor = "0.110";
        stealthchop_threshold = 500;
      };

      heater_bed = {
        heater_pin = "PC15";
        max_power = "0.8";
        max_temp = 125;
        min_temp = 0;

        sensor_pin = "PC3";
        sensor_type = "NTC 100K beta 3950";

        control = "pid";
        pid_kd = "261.522";
        pid_ki = "2.306";
        pid_kp = "49.112";
        smooth_time = "3.0";
      };

      printer = {
        kinematics = "corexy";
        max_accel = 2500;
        max_velocity = 300;
        max_z_accel = 30;
        max_z_velocity = 20;
        square_corner_velocity = "5.0";
      };

      "heater_fan hotend_fan" = {
        heater = "extruder";
        heater_temp = "50.0";
        max_power = "1.0";
        pin = "PC6";
        fan_speed = "1.0";
      };

      fan = {
        cycle_time = "0.010";
        kick_start_time = "0.5";
        off_below = "0.13";
        pin = "PC9";
      };

      idle_timeout.timeout = 7200;

      homing_override = {
        axes = "z";
        set_position_z = 0;
        gcode = "
    G90
    G0 Z1 F600
    G28 X Y
    G0 X0 Y0 F3600

    G28 Z
    G0 Z5 F10000
        ";
      };

      bed_screws = {
        screw1 = "60,5";
        screw1_name = "front screw";
        screw2 = "5,115";
        screw2_name = "back left";
        screw3 = "115,115";
        screw3_name = "back right";
      };

      "gcode_macro PRINT_START".gcode = "
    M107                  ; turn off fans
    M140 S{BED_TEMP}      ; start heating bed
    M104 S{EXTRUDER_TEMP} ; start heating hotend
    G90                   ; absolute positioning
    G28                   ; zero axis
    G1 X1 Y4 Z0.1 F5000   ; move to bottom left corner
    M190 S{BED_TEMP}      ; wait on bed temp
    M109 S{EXTRUDER_TEMP} ; wait on hotend temp
      ";

      "gcode_macro PRINT_END".gcode = "
    M400                           ; wait for buffer to clear
    G92 E0                         ; zero the extruder
    G1 E-4.0 F3000                 ; retract filament
    G91                            ; relative positioning
    G0 Z0.4 F10000                 ; move nozzle up
    G90                            ; absolute positioning
    G0 X118 Y120 F20000            ; move nozzle to remove stringing
    TURN_OFF_HEATERS
    M107                           ; turn off fan
    G0 Z120 F10000                 ; move bed all the way down
    M18                            ; turn off motors
      ";

      "gcode_macro LOAD_FILAMENT".gcode = "
    M83                            ; set extruder to relative
    G1 E300 F1800                  ; quickly load filament to down bowden
    G1 E50 F300                    ; slower extrusion for hotend path
    G1 E30 F150                    ; prime nozzle with filament
    M82                            ; set extruder to absolute
      ";

      "gcode_macro UNLOAD_FILAMENT".gcode = "
    M83                            ; set extruder to relative
    G1 E10 F300                    ; extrude a little to soften tip
    G1 E-380 F1800                 ; retract filament completely
    M82                            ; set extruder to absolute
      ";

      "static_digital_output usb_pullup_enable".pins = "!PA14";

      board_pins.aliases = "EXP1_1=PB5, EXP1_3=PA9, EXP1_5=PA10, EXP1_7=PB8, EXP1_9=<GND>, EXP1_2=PA15, EXP1_4=<RST>, EXP1_6=PB9, EXP1_8=PB15, EXP1_10=<5V>";

      "menu __main __prepare" = {
        type = "list";
        enable = "{not printer.idle_timeout.state == \"Printing\"}";
        name = "Prepare";
      };

      "menu __main __prepare __bedScrew" = {
        type = "list";
        name = "Bed Screw Tune";
      };

      "menu __main __prepare __bedScrew __Start" = {
        type = "command";
        name = "Start Screw Adjust";
        gcode = "
    G28 X0 Y0
    G28 Z0
    BED_SCREWS_ADJUST
        ";
      };

      "menu __main __prepare __bedScrew __Accept" = {
        type = "command";
        name = "Accept";
        gcode = "
    ACCEPT
        ";
      };

      "menu __main __prepare __bedScrew __Adjusted" = {
        type = "command";
        name = "Adjusted";
        gcode = "
    ADJUSTED
        ";
      };

      "menu __main __prepare __bedScrew __Abort" = {
        type = "command";
        name = "Abort";
        gcode = "
    ABORT
        ";
      };

      "display_glyph voron".data = "
 ......***.......
 ....*******.....
 ...*********....
 .*************..
 *****..***..***.
 ****..***..****.
 ***..***..*****.
 **..***..******.
 ******..***..**.
 *****..***..***.
 ****..***..****.
 ***..***..*****.
 .*************..
 ...*********....
 ....*******.....
 ......***.......
      ";

      "display_template _vheater_temperature" = {
        param_heater_name = "\"extruder\"";
        text = "
  {% if param_heater_name in printer %}
    {% set heater = printer[param_heater_name] %}
    # Show glyph
    {% if param_heater_name == \"heater_bed\" %}
      {% if heater.target %}
        {% set frame = (printer.toolhead.estimated_print_time|int % 2) + 1 %}
        ~bed_heat{frame}~
      {% else %}
        ~bed~
      {% endif %}
    {% else %}
      ~extruder~
    {% endif %}
    # Show temperature
    { \"%3.0f\" % (heater.temperature,) }
    # Optionally show target
    {% if heater.target and (heater.temperature - heater.target)|abs > 2 %}
      ~right_arrow~
      { \"%0.0f\" % (heater.target,) }
    {% endif %}
    ~degrees~
    {% endif %}
  ";
      };

      "display_data __voron_display extruder" = {
        position = "1, 0";
        text = "{ render(\"_vheater_temperature\", param_heater_name=\"extruder\") }";
      };

      "display_data __voron_display fan" = {
        position = "0, 10";
        text = "
  {% if 'fan' in printer %}
    {% set speed = printer.fan.speed %}
    {% if speed %}
      {% set frame = (printer.toolhead.estimated_print_time|int % 2) + 1 %}
      ~fan{frame}~
    {% else %}
      ~fan1~
    {% endif %}
    { \"{:>4.0%}\".format(speed) }
  {% endif %}
        ";
      };

      "display_data __voron_display bed" = {
        position = "2, 0";
        text = "{ render(\"_vheater_temperature\", param_heater_name=\"heater_bed\") }";
      };

      "display_data __voron_display print_serial" = {
        position = "0, 0";
        text = "
  { \"V0.156 \" }
    ~voron~
        ";
      };


      "display_data __voron_display progress_text" = {
        position = "2, 10";
        text = "
  {% set progress = printer.display_status.progress %}
  { \"{:^6.0%}\".format(progress) }
        ";
      };

      "display_data __voron_display progress_text2" = {
        position = "1, 10";
        text = "
  {% set progress = printer.display_status.progress %}
  { draw_progress_bar(1, 10, 6, progress) }
        ";
      };

      "display_data __voron_display printing_time" = {
        position = "2, 10";
        text = "
  {% set ptime = printer.idle_timeout.printing_time %}
  { \"%02d:%02d\" % (ptime // (60 * 60), (ptime // 60) % 60) }
        ";
      };

      "display_data __voron_display print_status" = {
        position = "3, 0";
        text = "
  {% if printer.display_status.message %}
    { printer.display_status.message }
  {% elif printer.idle_timeout.printing_time %}
    {% set pos = printer.toolhead.position %}
    { \"X%-4.0fY%-4.0fZ%-5.2f\" % (pos.x, pos.y, pos.z) }
  {% endif %}
        ";
      };
    };
  };
}
