# frozen_string_literal: true

module ProgramDirector
  # FR-054 Detail, FR-055 (Assessment Summary Report), FR-056 (Visualizations)
  # Aggregates and normalizes complete 6-week assessment data for a student's cycle:
  # - Student info
  # - Assessment cycle info
  # - Skills assessment (ABLLS results, domain performance, need analysis, strengths, areas of need)
  # - Behavior assessment (MASS/FAST/ABC structure with graceful placeholders)
  # - Preference assessment (ranked top preferences)
  # - Visualizations (skills radar, behavior function summary, top preferences)
  class AssessmentSummaryService < ApplicationService
    def initialize(assessment_cycle_id:)
      @assessment_cycle_id = assessment_cycle_id
    end

    def call
      cycle = find_assessment_cycle
      return failure("Assessment cycle not found") unless cycle

      student = cycle.student
      ablls = cycle.ablls_assessment
      preference = cycle.preference_assessment
      sensory = SensoryAssessment.find_by(student_id: student.id)

      skills_data = build_skills_summary(ablls)
      behavior_data = build_behavior_summary(sensory)
      preference_data = build_preference_summary(preference)
      visualizations_data = build_visualizations(skills_data, behavior_data, preference_data)

      overall_progress = calculate_overall_progress(
        cycle: cycle,
        skills_progress: skills_data[:progress][:completion_percentage],
        preference_status: preference_data[:status],
        behavior_status: behavior_data[:status]
      )

      payload = {
        student: {
          id: student.id,
          name: student.full_name,
          first_name: student.first_name,
          last_name: student.last_name,
          age: student.age,
          date_of_birth: student.date_of_birth,
          diagnosis: student.diagnosis,
          program_type: student.program_type,
          therapy_group: student.therapy_group,
          status: student.status
        },
        assessment: {
          id: cycle.id,
          assessment_id: cycle.id,
          status: cycle.status,
          progress: overall_progress,
          started_on: cycle.started_on,
          completed_on: cycle.completed_on,
          created_at: cycle.created_at,
          updated_at: cycle.updated_at
        },
        skills: skills_data,
        behavior: behavior_data,
        preferences: preference_data,
        visualizations: visualizations_data,
        # Direct top-level access for standard visualization & report consumers
        skills_radar: visualizations_data[:skills_radar],
        behavior_function_summary: visualizations_data[:behavior_function_summary],
        top_preferences: visualizations_data[:top_preferences],
        strengths: skills_data[:strengths],
        areas_of_need: skills_data[:areas_of_need],
        need_analysis: skills_data[:need_analysis]
      }

      success(payload)
    end

    private

    def find_assessment_cycle
      AssessmentCycle.includes(
        :student,
        ablls_assessment: { ablls_responses: { ablls_skill_item: :ablls_domain } }
      ).find_by(id: @assessment_cycle_id) ||
        AssessmentCycle.includes(
          :student,
          ablls_assessment: { ablls_responses: { ablls_skill_item: :ablls_domain } }
        ).where(student_id: @assessment_cycle_id).order(started_on: :desc).first
    end

    # ── Skills / ABLLS ──────────────────────────────────────────────────────────

    def build_skills_summary(ablls)
      unless ablls
        return {
          id: nil,
          status: "not_started",
          overall_score: 0,
          progress: { total_items: 0, completed_items: 0, completion_percentage: 0 },
          domains: [],
          need_analysis: [],
          strengths: [],
          areas_of_need: []
        }
      end

      progress_res = AbllsAssessments::ProgressService.call(ablls_assessment: ablls)
      need_res = AbllsAssessments::NeedAnalysisService.call(ablls_assessment: ablls)

      progress_data = progress_res.success? ? progress_res.data : {}
      need_domains = need_res.success? ? need_res.data[:domains] : []

      domains_payload = serialize_ablls_domains(ablls, need_domains)
      strengths = extract_strengths(domains_payload)
      areas_of_need = extract_areas_of_need(need_domains)

      overall_score = calculate_overall_ablls_score(domains_payload)

      {
        id: ablls.id,
        status: ablls.status,
        started_at: ablls.started_at,
        completed_at: ablls.completed_at,
        overall_score: overall_score,
        progress: progress_data,
        domains: domains_payload,
        need_analysis: need_domains,
        strengths: strengths,
        areas_of_need: areas_of_need
      }
    end

    def serialize_ablls_domains(ablls, need_domains)
      need_by_domain_id = need_domains.index_by { |nd| nd[:domain_id] }
      responses_by_item = ablls.ablls_responses.index_by(&:ablls_skill_item_id)

      AbllsDomain.active.ordered.includes(:ablls_skill_items).map do |domain|
        items = domain.ablls_skill_items.select(&:is_active).sort_by(&:position)
        domain_responses = items.map { |item| responses_by_item[item.id] }.compact

        scored_responses = domain_responses.select { |r| r.score.present? }
        valid_score_responses = scored_responses.reject { |r| r.score == "not_applicable" }

        # Calculate clinical domain performance
        # 0 = 0 pts, 1 = 1 pt, 2 = 2 pts. Max = non-N/A scored items * 2
        total_points = valid_score_responses.sum do |r|
          case r.score
          when "2" then 2
          when "1" then 1
          else 0
          end
        end

        max_possible_points = valid_score_responses.size * 2
        performance_percentage = if max_possible_points.positive?
                                   ((total_points.to_f / max_possible_points) * 100).round
        else
                                   0
        end

        need_info = need_by_domain_id[domain.id] || {}

        {
          id: domain.id,
          code: domain.code,
          name: domain.name,
          position: domain.position,
          total_items: items.size,
          scored_items: scored_responses.size,
          score_0_count: need_info[:score_0_count] || 0,
          score_1_count: need_info[:score_1_count] || 0,
          score_2_count: need_info[:score_2_count] || 0,
          not_applicable_count: need_info[:not_applicable_count] || 0,
          need_count: need_info[:need_count] || 0,
          total_points: total_points,
          max_possible_points: max_possible_points,
          percentage: performance_percentage,
          score: performance_percentage,
          items: items.map do |item|
            resp = responses_by_item[item.id]
            {
              id: item.id,
              identifier: item.identifier,
              description: item.description,
              score: resp&.score,
              note: resp&.note
            }
          end
        }
      end
    end

    def extract_strengths(domains_payload)
      # Domains with >= 70% performance, sorted highest first
      domains_payload
        .select { |d| d[:scored_items].positive? && d[:percentage] >= 70 }
        .sort_by { |d| -d[:percentage] }
        .map do |d|
          {
            domain_id: d[:id],
            domain_code: d[:code],
            domain: d[:name],
            percentage: d[:percentage],
            score: d[:score]
          }
        end
    end

    def extract_areas_of_need(need_domains)
      # Domains with need_count > 0, sorted by need_count descending
      need_domains
        .select { |nd| nd[:need_count].to_i.positive? }
        .sort_by { |nd| -nd[:need_count] }
        .map do |nd|
          {
            domain_id: nd[:domain_id],
            domain_code: nd[:domain_code],
            domain: nd[:domain_name],
            score_0: nd[:score_0_count],
            score_1: nd[:score_1_count],
            need_count: nd[:need_count]
          }
        end
    end

    def calculate_overall_ablls_score(domains_payload)
      scored_domains = domains_payload.select { |d| d[:max_possible_points].positive? }
      return 0 if scored_domains.empty?

      total_pts = scored_domains.sum { |d| d[:total_points] }
      total_max = scored_domains.sum { |d| d[:max_possible_points] }

      total_max.positive? ? ((total_pts.to_f / total_max) * 100).round : 0
    end

    # ── Behavior Assessment ─────────────────────────────────────────────────────

    def build_behavior_summary(sensory)
      # Structured response adhering to SRS; behavior models (MASS/FAST) are not yet in codebase
      {
        status: sensory&.status == "complete" ? "complete" : "not_started",
        mass: {
          status: "pending_implementation",
          scores: {},
          summary: "MASS behavior assessment models pending implementation in backend"
        },
        fast: {
          status: "pending_implementation",
          scores: {},
          summary: "FAST behavior assessment models pending implementation in backend"
        },
        abc_summary: {
          status: "pending_implementation",
          incidents_count: 0,
          common_antecedents: [],
          common_behaviors: [],
          common_consequences: []
        },
        functions: [
          { function: "Attention", score: 0, percentage: 0 },
          { function: "Escape", score: 0, percentage: 0 },
          { function: "Tangible", score: 0, percentage: 0 },
          { function: "Sensory", score: 0, percentage: 0 }
        ],
        sensory_assessment: sensory ? { id: sensory.id, status: sensory.status, summary: sensory.summary } : nil
      }
    end

    # ── Preference Assessment ───────────────────────────────────────────────────

    def build_preference_summary(preference)
      unless preference
        return {
          id: nil,
          status: "not_started",
          top_preferences: [],
          ranked_observations: []
        }
      end

      ranked_obs = preference.ranked_observations.to_a

      top_prefs = ranked_obs.select(&:engaged?).first(5).map.with_index(1) do |obs, idx|
        {
          rank: obs.rank || idx,
          name: obs.item_name,
          category: obs.item_category,
          tier: obs.tier,
          combined_score: obs.combined_score.to_f,
          context: obs.context
        }
      end

      {
        id: preference.id,
        status: preference.status,
        submitted_at: preference.submitted_at,
        top_preferences: top_prefs,
        ranked_observations: ranked_obs.map do |obs|
          {
            id: obs.id,
            rank: obs.rank,
            name: obs.item_name,
            category: obs.item_category,
            context: obs.context,
            tier: obs.tier,
            duration_seconds: obs.duration_seconds,
            frequency_count: obs.frequency_count,
            combined_score: obs.combined_score.to_f,
            notes: obs.notes
          }
        end
      }
    end

    # ── Visualizations (FR-056) ─────────────────────────────────────────────────

    def build_visualizations(skills_data, behavior_data, preference_data)
      # 1. Skills Radar Chart
      skills_radar = skills_data[:domains].map do |d|
        {
          domain: d[:name],
          domain_code: d[:code],
          score: d[:score],
          percentage: d[:percentage]
        }
      end

      # 2. Behavior Function Summary (default 4 standard functions)
      behavior_functions = behavior_data[:functions] || [
        { function: "Attention", score: 0, percentage: 0 },
        { function: "Escape", score: 0, percentage: 0 },
        { function: "Tangible", score: 0, percentage: 0 },
        { function: "Sensory", score: 0, percentage: 0 }
      ]

      # 3. Top Preferences
      top_preferences = preference_data[:top_preferences].map do |tp|
        {
          rank: tp[:rank],
          name: tp[:name],
          category: tp[:category]
        }
      end

      {
        skills_radar: skills_radar,
        behavior_function_summary: behavior_functions,
        top_preferences: top_preferences
      }
    end

    def calculate_overall_progress(cycle:, skills_progress:, preference_status:, behavior_status:)
      return 100 if cycle.status.in?(%w[complete reviewed])

      skills_pct = skills_progress.to_i
      pref_pct = preference_status == "submitted" ? 100 : (preference_status == "draft" ? 50 : 0)
      beh_pct = behavior_status == "complete" ? 100 : (behavior_status == "in_progress" ? 50 : 0)

      ((skills_pct + pref_pct + beh_pct) / 3.0).round.clamp(0, 100)
    end
  end
end
