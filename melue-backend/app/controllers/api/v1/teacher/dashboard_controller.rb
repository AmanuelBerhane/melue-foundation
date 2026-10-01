# frozen_string_literal: true

class Api::V1::Teacher::DashboardController < Api::V1::BaseController
  before_action :authenticate_user!

  def show
    students = Student.all.limit(10).map do |s|
      full_name = "#{s.first_name} #{s.last_name}".strip
      {
        id: s.id.to_s,
        name: full_name,
        initial: full_name[0] || "S"
      }
    end

    schedule_students = students.first(2)

    station = TherapyStation.first
    room = TherapyRoom.first
    block = SessionBlockDefinition.first

    today_schedule = {
      stationName: station&.name || "Station 1 — Basic Skills",
      roomName: room&.name || "Room 1A",
      sessionBlock: block&.name || "Morning Block A · Daily Living",
      startTime: block&.start_time ? block.start_time.strftime("%I:%M %p") : "08:00 AM",
      endTime: block&.end_time ? block.end_time.strftime("%I:%M %p") : "09:30 AM",
      startsIn: "Starts in 15m",
      students: schedule_students
    }

    assessment_tasks = students.map do |s|
      {
        id: "assess-#{s[:id]}",
        studentName: s[:name],
        studentInitial: s[:initial],
        assessmentName: "ABLLS Assessment",
        status: "In Progress",
        progress: 45
      }
    end

    notifications = Notification.for_recipient(current_user.id).limit(5).map do |n|
      title = begin
        n.payload["title"] || n.type.humanize
      rescue StandardError
        n.type.humanize
      end
      {
        id: n.id.to_s,
        type: "alert",
        title: title,
        source: "System",
        timeAgo: "Just now",
        unread: !n.read?
      }
    end

    render json: {
      todaySchedule: today_schedule,
      assessmentTasks: assessment_tasks,
      pendingMasteryChecks: [],
      notifications: notifications
    }
  end

  def assessments
    students = Student.all.limit(10).map do |s|
      full_name = "#{s.first_name} #{s.last_name}".strip
      {
        id: s.id.to_s,
        fullName: full_name,
        name: full_name,
        initial: full_name[0] || "S",
        ablls: { status: "in_progress", progress: 45 },
        behavior: { status: "not_started", progress: 0 }
      }
    end

    render json: { students: students }
  end
end
