module Api::V1
  class BaseController < ApplicationController
    rescue_from ApplicationError do |e|
      render_error(e.status, e.message)
    end

    rescue_from ActiveRecord::RecordNotFound do |_e|
      render_error(:not_found, "Resource not found")
    end

    rescue_from ActiveRecord::RecordNotUnique do |_e|
      render_error(:conflict, "Resource already exists")
    end

    rescue_from ActionController::ParameterMissing do |e|
      render_error(:bad_request, e.message)
    end

    rescue_from ActiveRecord::RecordInvalid do |e|
      render_validation_errors(e.record)
    end

    private

    def render_error(status, message)
      render json: { message: message }, status: status
    end

    def render_validation_errors(record)
      render json: {
        message: record.errors.map { |e| { field: e.attribute, message: e.full_message } }
      }, status: :unprocessable_content
    end
  end
end
