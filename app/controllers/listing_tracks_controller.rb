class ListingTracksController < ApplicationController
  FILTERS = %w[all favorites contacted visited rejected].freeze
  PER_PAGE = 24

  def index
    @status = params[:status].presence_in(FILTERS) || "all"
    scope = current_user.listing_tracks.with_history
    scope = case @status
    when "favorites" then scope.where(favorite: true)
    when "contacted" then scope.where.not(contacted_on: nil)
    when "visited" then scope.where.not(visited_on: nil)
    when "rejected" then scope.where.not(rejected_on: nil)
    else scope
    end
    @total_pages = [(scope.count.to_f / PER_PAGE).ceil, 1].max
    @page = params[:page].to_i.clamp(1, @total_pages)
    @tracks = scope.order(updated_at: :desc, id: :desc).offset((@page - 1) * PER_PAGE).limit(PER_PAGE)
  end

  def create
    listing = Listing.includes(:listing_source).find(params[:listing_id])
    identity = ListingTrack.identity_for(listing)
    # Serialize creation for this user; the unique index also guards the identity.
    current_user.with_lock do
      track = current_user.listing_tracks.find_or_initialize_by(identity)
      persist = -> { track.capture_listing(listing); save_track(track) }
      track.persisted? ? track.with_lock(&persist) : persist.call
    end
  rescue ActiveRecord::RecordNotFound
    head :not_found
  end

  def update
    track = current_user.listing_tracks.find(params[:id])
    track.with_lock do
      if params[:listing_id].present?
        listing = Listing.includes(:listing_source).find(params[:listing_id])
        identity = ListingTrack.identity_for(listing)
        return head :not_found unless identity == track.attributes.symbolize_keys.slice(:source_key, :source_identity)

        track.capture_listing(listing)
      end
      save_track(track)
    end
  rescue ActiveRecord::RecordNotFound
    head :not_found
  end

  private

  def save_track(track)
    saved = track.update(track_params)
    if request.format.turbo_stream?
      @status = params[:status].presence_in(FILTERS) || "all"
      @page = params[:page]
      @feed_params = params.fetch(:feed_params, ActionController::Parameters.new).permit(*ListingsController::FILTER_PARAMS).to_h
      @active_search = current_user.search_preferences.find_by(id: params[:search_id])
      listing = params[:return_to] == "feed" ? track.listing : nil
      target = listing ? "listing_tracking_#{listing.id}" : "saved_tracking_#{track.id}"
      stream = if saved && !listing && !visible_in_status?(track)
        turbo_stream.remove("tracked_apartment_#{track.id}")
      else
        turbo_stream.replace(target, partial: "listing_tracks/form", locals: { track: track, listing: listing, return_to: params[:return_to], saved: saved })
      end
      render turbo_stream: stream, status: saved ? :ok : :unprocessable_entity
    elsif saved
      if params[:return_to] == "feed"
        filters = params.fetch(:feed_params, ActionController::Parameters.new).permit(*ListingsController::FILTER_PARAMS).to_h
        redirect_to listings_path(filters.merge(search_id: params[:search_id], page: params[:page])), notice: t("tracking.saved"), status: :see_other
      else
        redirect_to listing_tracks_path(status: params[:status]), notice: t("tracking.saved"), status: :see_other
      end
    else
      @track = track
      render :edit, status: :unprocessable_entity
    end
  end

  def visible_in_status?(track)
    case @status
    when "favorites" then track.favorite?
    when "contacted", "visited", "rejected" then track.public_send("#{@status}_on").present?
    else track.favorite? || ListingTrack::DATE_FIELDS.any? { |field| track.public_send(field).present? }
    end
  end

  def track_params
    params.require(:listing_track).permit(:favorite, :contacted_on, :visited_on, :rejected_on)
  end
end
