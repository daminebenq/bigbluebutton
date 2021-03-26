# Set encoding to utf-8
# encoding: UTF-8

#
# BigBlueButton open source conferencing system - http://www.bigbluebutton.org/
#
# Copyright (c) 2012 BigBlueButton Inc. and by respective authors (see below).
#
# This program is free software; you can redistribute it and/or modify it under the
# terms of the GNU Lesser General Public License as published by the Free Software
# Foundation; either version 3.0 of the License, or (at your option) any later
# version.
#
# BigBlueButton is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
# PARTICULAR PURPOSE. See the GNU Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public License along
# with BigBlueButton; if not, see <http://www.gnu.org/licenses/>.
#


require 'fileutils'
require 'rubygems'
require 'nokogiri'
require 'builder'

module BigBlueButton
  class AudioEvents

    def self.create_audio_edl(events, archive_dir)
      audio_edl = []
      audio_dir = "#{archive_dir}/audio"

      initial_timestamp = BigBlueButton::Events.first_event_timestamp(events)
      final_timestamp = BigBlueButton::Events.last_event_timestamp(events)

      # Initially start with silence
      audio_edl << {
        :timestamp => 0,
        :audio => nil
      }

      # Add events for recording start/stop
      events.xpath('/recording/event[@module="VOICE"]').each do |event|
        timestamp = event['timestamp'].to_i - initial_timestamp
        case event['eventname']
        when 'StartRecordingEvent'
          filename = event.at_xpath('filename').text
          filename = "#{audio_dir}/#{File.basename(filename)}"
          audio_edl << {
            :timestamp => timestamp,
            :audio => { :filename => filename, :timestamp => 0 }
          }
        when 'StopRecordingEvent'
          filename = event.at_xpath('filename').text
          filename = "#{audio_dir}/#{File.basename(filename)}"
          if audio_edl.last[:audio] && audio_edl.last[:audio][:filename] == filename
            audio_edl.last[:original_duration] = timestamp - audio_edl.last[:timestamp]
            audio_edl << {
              :timestamp => timestamp,
              :audio => nil
            }
          end
        end
      end

      audio_edl << {
        :timestamp => final_timestamp - initial_timestamp,
        :audio => nil
      }

      return audio_edl
    end

    def self.create_deskshare_audio_edl(events, deskshare_dir)
      audio_edl = []

      initial_timestamp = BigBlueButton::Events.first_event_timestamp(events)
      final_timestamp = BigBlueButton::Events.last_event_timestamp(events)
      filename = ""

      # Initially start with silence
      audio_edl << {
        :timestamp => 0,
        :audio => nil
      }

      events.xpath('/recording/event[@module="bbb-webrtc-sfu" and (@eventname="StartWebRTCDesktopShareEvent" or @eventname="StopWebRTCDesktopShareEvent")]').each do |event|
        filename = event.at_xpath('filename').text
        # Determine the audio filename
        case event['eventname']
        when 'StartWebRTCDesktopShareEvent', 'StopWebRTCDesktopShareEvent'
          uri = event.at_xpath('filename').text
          filename = "#{deskshare_dir}/#{File.basename(uri)}"
        end
        raise "Couldn't determine audio filename" if filename.nil?
        # check if deskshare has audio
        fileHasAudio = !BigBlueButton::EDL::Audio.audio_info(filename)[:audio].nil?
        if (fileHasAudio)
          timestamp = event['timestamp'].to_i - initial_timestamp
          # Add the audio to the EDL
          case event['eventname']
          when 'StartWebRTCDesktopShareEvent'
            audio_edl << {
              :timestamp => timestamp,
              :audio => { :filename => filename, :timestamp => 0 }
            }
          when 'StopWebRTCDesktopShareEvent'
            if audio_edl.last[:audio] && audio_edl.last[:audio][:filename] == filename
              # Fill in the original/expected audo duration when available
              duration = event.at_xpath('duration')
              if !duration.nil?
                duration = duration.text.to_i
                audio_edl.last[:original_duration] = duration * 1000
              else
                audio_edl.last[:original_duration] = timestamp - audio_edl.last[:timestamp]
              end
              audio_edl << {
                :timestamp => timestamp,
                :audio => nil
              }
            end
          end
        else
          BigBlueButton.logger.debug " Screenshare without audio, ignoring..."
        end
      end

      audio_edl << {
        :timestamp => final_timestamp - initial_timestamp,
        :audio => nil
      }

      return audio_edl
    end

  end
end
