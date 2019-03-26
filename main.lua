--[[============================================================================
main.lua
============================================================================]]--
require 'scale'

local scale_root = 4
local scale_type = 1
local scale_pattern
local ccont = {}

local vb = renoise.ViewBuilder()
local sdisplay = vb:text{ width = 190, font = 'bold' }
local cdisplay = vb:text{ width = 160, font = 'bold', text = 'Chord  [none selected]' }

local cb_headers = { 'I', 'ii', 'iii', 'IV', 'V', 'vi', 'vii' }
local chord_boxes = {}
for i = 1, 12 do
  chord_boxes[i] = vb:column { 
    style = 'panel', 
    vb:text{ 
      align = 'center',
      width = 60,
      font = 'bold', 
      text = cb_headers[i] 
    }
  }
end


------
local OscMessage = renoise.Osc.Message
local OscBundle = renoise.Osc.Bundle

-- open a socket connection to the server
local client, socket_error = renoise.Socket.create_client(
"127.0.0.1", 8000, renoise.Socket.PROTOCOL_UDP)


if (socket_error) then
renoise.app():show_warning(("Failed to start the " ..
"OSC client. Error: '%s'"):format(socket_error))
return
end


--------------------------------------------------------------------------------
function start_preview()  
  --renoise.song().transport:start_at(renoise.song().selected_line_index)
end

--------------------------------------------------------------------------------
function stop_preview(root, chord)
  --renoise.song().transport:stop()
 local cpattern = chord["pattern"]
  local res = ''
  local note_offset = 0
  local current_instrument = renoise.song().selected_instrument_index
  
  for n = 1, #cpattern do
    if cpattern:sub(n, n) == '1' then
      local note = root + n - 1;
      -- Form the string for chord note listing
      if res ~= '' then 
        res = res .. ', '
      else
        res = 'Chord ' ..  get_nname(root) .. chord["code"] .. ': '
      end
      res = res .. get_nname(note)
     
      -- Insert note
--      print(renoise.song().transport.edit_mode)

 --     if(renoise.song().transport.edit_mode) then
 --     insert_note(note, note_offset, current_instrument)
 --     print(cpattern)
 --     print(res)
 --     print(chord["code"])
 --     print(note)
  
     client:send(OscMessage("/renoise/trigger/note_off", {
     { tag="i", value=current_instrument},
     { tag="i", value=-1},
     { tag="i", value=(note-4) + renoise.song().transport.octave * 12}
     }
     ))
--     end
      
      
      
      
     
    end
  end
 
end

--------------------------------------------------------------------------------
function insert_note(note, col, insv)
  if renoise.song().selected_note_column_index == 0 then
    return -- Don't enter notes when in effect column
  end
   
  col = col + renoise.song().selected_note_column_index - 1
  
  -- Get the note column
  local nc = renoise.song().selected_line.note_columns[col + 1]
  
  -- Add note
  nc.note_value = note - 4 + renoise.song().transport.octave * 12
  nc.instrument_value = insv - 1
 -- print(nc.note_value)
--  print("\n")
  
  
  -- Not enough space? Compensate!
  if col >= renoise.song().selected_track.visible_note_columns then
    renoise.song().selected_track.visible_note_columns = col + 1
  end
  
  -- Preview
  start_preview()
  
end

function clear_cb()
  for i, v in ipairs(ccont) do
    if v ~= nil then
      chord_boxes[i]:remove_child(v)
      chord_boxes[i]:resize()
      ccont[i] = nil
    end 
  end
end

--------------------------------------------------------------------------------
function add_chord(root, chord)
  cdisplay.text = 'Chord: ' .. get_note(root) .. chord["code"]
  local cpattern = chord["pattern"]
  local res = ''
  local note_offset = 0
  local current_instrument = renoise.song().selected_instrument_index
  
  for n = 1, #cpattern do
    if cpattern:sub(n, n) == '1' then
      local note = root + n - 1;
      -- Form the string for chord note listing
      if res ~= '' then 
        res = res .. ', '
      else
        res = 'Chord ' ..  get_nname(root) .. chord["code"] .. ': '
      end
      res = res .. get_nname(note)
     
      -- Insert note
--      if(renoise.song().transport.edit_mode) then
 --     insert_note(note, note_offset, current_instrument)
--      print(cpattern)
--      print(res)
--      print(chord["code"])
--      print(note)
--      end
  

      
     
      client:send(OscMessage("/renoise/trigger/note_on", {
      { tag="i", value=current_instrument},
      { tag="i", value=-1},
      { tag="i", value=(note-4) + renoise.song().transport.octave * 12},
      { tag="i", value=renoise.song().transport.keyboard_velocity}
      }
      
      ))
 --     print(renoise.song().transport.keyboard_velocity)
      
      
      note_offset = note_offset + 1
    end
  end
 
  -- OFF rest of the notes
  local vnc = renoise.song().selected_track.visible_note_columns
 if vnc > note_offset then
   for i = note_offset + 1,vnc do
     local nc = renoise.song().selected_line.note_columns[i]
     nc.note_value = 120
     nc.instrument_value = 255
   end
 end 
  cdisplay.text = res
end
--------------------------------------------------------------------------------
function send_note(note, note_offset)
end
------
function update()
  clear_cb()
  scale_pattern = get_scale(scale_root, scales[scale_type])
  local res = ''
  local sn = 0
  for n = scale_root, scale_root + 11 do
    if scale_pattern[get_note(n)] then
      -- Form the string for scale note listing
      if res ~= '' then 
        res = res .. ', '
      else
        res = 'Scale: '
      end
      res = res .. get_nname(n)
      
      -- Build the chord views
      sn = sn + 1
      local cc = vb:column {} -- Chord Container
      ccont[sn] = cc
      chord_boxes[sn]:add_child(cc)
      for k, c in ipairs(chords) do
        if is_valid(n, k, scale_pattern) then
          local cb = vb:button {
            width = 70,
            height = 30,
            text = get_nname(n) .. c['code'],
            pressed = function()
              add_chord(n, c)
            end,
            released = function()
              stop_preview(n, c)
            end
          }
          cc:add_child(cb)
        end
      end
    end
  end
  sdisplay.text = res
end

--------------------------------------------------------------------------------
snames = { }
for key, scale in ipairs(scales) do
  table.insert(snames,scale['name'])
end
local dialog_view

function create_dialog ()
  dialog_view = vb:column {  
    margin = renoise.ViewBuilder.DEFAULT_DIALOG_MARGIN,
    vb:column {
      spacing = renoise.ViewBuilder.DEFAULT_CONTROL_SPACING,
      vb:row {
        spacing = renoise.ViewBuilder.DEFAULT_CONTROL_SPACING,
        margin = renoise.ViewBuilder.DEFAULT_CONTROL_MARGIN,
        width = 700,
        style = 'group',
        vb:text { text = 'Key:' },
        vb:popup { 
          items = notes, 
          value = scale_root,
          notifier = function (i) scale_root = i; update() end 
        },
        vb:text { text = ' Scale:' },
        vb:popup { 
          items = snames,  
          value = scale_type,
          notifier = function (i) scale_type = i; update() end  
        },
        sdisplay
      },
      vb:column {
        style = 'group',
        margin = renoise.ViewBuilder.DEFAULT_CONTROL_MARGIN,
        spacing = renoise.ViewBuilder.DEFAULT_CONTROL_SPACING,
        height = 200,
        cdisplay,
        vb:row{
          chord_boxes[1], 
          chord_boxes[2], 
          chord_boxes[3], 
          chord_boxes[4], 
          chord_boxes[5], 
          chord_boxes[6], 
          chord_boxes[7]
        }
      }
    }
  }
end

function handle_keys(d, k)
 -- print(k.name)
  if k.name == 'esc' then
  --  d:close()
  else 
    return k
  end
end

--------------------------------------------------------------------------------
local dialog
function display()
  update()
  
  if dialog_view == nil then
    create_dialog()
  end
  
  if dialog == nil or not dialog.visible then
    dialog = renoise.app():show_custom_dialog('Scale finder', 
        dialog_view, handle_keys )
  end
end

--------------------------------------------------------------------------------
-- menu registration
--------------------------------------------------------------------------------

renoise.tool():add_menu_entry {
   name = "Main Menu:Tools:Scale finder...",
   invoke = display
}
