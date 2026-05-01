MZTargetConfig = {
  debug = false,
  open_key = 'LMENU',
  open_label = 'ALT ESQ',
  primary_control = 24,
  primary_label = 'Clique esquerdo',
  menu_control = 25,
  menu_label = 'Botao direito',
  menu_cursor_x = 0.58,
  menu_cursor_y = 0.5,
  loop_active_ms = 0,
  loop_idle_ms = 180,
  raycast_distance = 6.0,
  drop = {
    label = 'Abrir bolsa no chao',
    max_distance = 2.5,
    aim_threshold = 0.18,
    stream_distance = 120.0,
    prop_model = 'bkr_prop_duffel_bag_01a',
    heading_offset = 0.0
  },
  vehicle = {
    trunk = {
      label = 'Abrir porta-malas',
      max_distance = 3.1,
      aim_threshold = 0.18,
      raycast_hit_distance = 1.4,
      bones = { 'boot' },
      fallback_offsets = {
        vec3(0.0, -2.15, 0.45),
        vec3(0.0, -1.75, 0.72)
      }
    },
    glovebox = {
      label = 'Abrir porta-luvas',
      max_distance = 2.9,
      aim_threshold = 0.19,
      raycast_hit_distance = 1.45,
      bones = { 'seat_dside_f', 'seat_pside_f', 'door_dside_f', 'door_pside_f' },
      door_indices = {
        seat_dside_f = 0,
        seat_pside_f = 1,
        door_dside_f = 0,
        door_pside_f = 1
      },
      fallback_offsets = {
        vec3(-0.92, 0.78, 0.52),
        vec3(0.92, 0.78, 0.52),
        vec3(-0.62, 0.28, 0.72),
        vec3(0.62, 0.28, 0.72)
      }
    }
  }
}
