Handlebars.registerHelper 'spinner', (context) ->
    "<span class='spinner'></span>"


Handlebars.registerHelper 'lfm_img', (size, context) ->    
    image = chromus.plugins.lastfm.image
        artist: context.artist || context.name,
        size: size


class Track extends Backbone.Model    

class Playlist extends Backbone.Collection
    model: Track


class Player extends Backbone.Model
    initialize: ->
        _.bindAll @, "listener"

        @playlist = new Playlist()

        @state = new Backbone.Model()

        browser.addMessageListener @listener

    
    currentTrack: ->
        @playlist.get @get 'current_track'        


    play: (track = @get('current_track')) ->
        @set 'current_track':track
        @playlist.trigger 'reset'

        @state.set 'name':'playing'

        browser.postMessage { method:'play', track: parseInt(track) }


    pause: ->
        @state.set 'name':'paused'
        
        browser.postMessage { method:'pause' }


    next: ->        
        browser.postMessage { method:'nextTrack' }


    listener: (msg) ->
        if !msg.method.match('(playerState|updateState)')
            console.log "Popup received message", msg.method, msg
        else
            if msg.state.name in ["playing", "loading"]                
                @playlist.get(msg.track.id).set(msg.track)
                @set 'current_track': msg.track.id
        
        
        @set 'settings': msg.settings if msg.settings?        
        @state.set msg.state if msg.state?
        
        @playlist.reset msg.playlist if msg.playlist
                


class Controls extends Backbone.View    

    el: $('#header') 

    search_template: Handlebars.compile($('#search_result_tmpl').html()),

    events:
        "click .toggle": "togglePlaying"
        "click .next":   "nextTrack"
        "click .search": "toggleSearch"
        "keyup .search_bar .text": "search"
        "click .search_bar .result a": "playSearchedTrack"

    initialize: ->
        _.bindAll @, "updateState", "togglePlaying", "search"

        @model.state.bind 'change', @updateState


    updateState: (state) ->
        state = state.toJSON()

        @$('.toggle')
            .removeClass('play pause')
            .addClass(
                if state.name is "playing" then 'play' else 'pause'
            )
        
        if state.duration        
            @$('.inner').width(276.0*state.played/state.duration)
            @$('.time').html prettyTime(state.played)

            state.buffered ?= 0
            @$('.progress').width(278.0*state.buffered/state.duration)


    togglePlaying: ->
        if @model.state.get('name') is "paused"
            @model.play()
        else
            @model.pause()        
    

    nextTrack: ->
        @model.next()

    
    toggleSearch: ->        
        bar = @$('.search_bar').toggle()

        bar.find('input').focus() if bar.is ':visible'
    
    # Rate limiting search function, by adding slight delay
    # http://documentcloud.github.com/underscore/#debounce
    search: _.debounce (evt) ->
        return if evt.keyCode in [40,45,37,39,38]        

        text = evt.currentTarget.value
        
        if not text.trim()
            @$('.search_bar .result').html('')
        else
            view =
                'show_tracks': (fn) -> if not @tracks or @tracks?.length then fn(this)
                'show_albums': (fn) -> if not @albums or @albums?.length then fn(this)
                'show_artists': (fn) -> if not @artists or @artists?.length then fn(this)

            render = =>
                @$('.search_bar .result').html(@search_template(view))
                    .end()
                    .find('.loader').spin('small');

            render()

            chromus.plugins.lastfm.artist.search text, (artists = []) =>
                view.artists = _.first(artists, 3)
                render()
            
            chromus.plugins.lastfm.track.search text, (tracks = []) =>
                view.tracks = _.first(tracks, 3)
                render()                            

            chromus.plugins.lastfm.album.search text, (albums = []) =>
                view.albums = _.first(albums, 3)
                render()
    , 500

    
    playSearchedTrack: (evt) ->
        track_info = getTrackInfo(evt.currentTarget)

        browser.postMessage
            method:   'play'
            track:    track_info
            playlist: [ track_info ]

        @toggleSearch()
                              

class TrackInfo extends Backbone.View
    el: $('#current_song')

    template: $('#track_info_tmpl')

    initialize: ->
        _.bindAll @, "updateInfo"

        @model.bind 'change:current_track', @updateInfo
        
                
    updateInfo: ->
        track = @model.currentTrack()?.toJSON()

        # If nothing playing, hide all info
        if not track
            return @el.empty()                      

        track.image = chromus.plugins.lastfm.image
            artist: track.artist
            song: track.song

        last_fm = "http://last.fm/music"
        track.artist_url = "#{last_fm}/#{track.artist}"
        track.album_url = "#{last_fm}/#{track.artist}/#{track.album}"
        track.song_url = "#{last_fm}/#{track.artist}/_/#{track.song}"
        
        @el.html(@template.tmpl(track))
            .show()


class Menu extends Backbone.View
    el: $('#wrapper')
    template: $('#main_menu_tmpl')

    events:
        "click #footer .button.menu": "toggleMenu"

    initialize: ->
        _.bindAll @, "toggleMenu"

    toggleMenu: ->
        @$('#main_menu').html(
            @template.tmpl settings: {}
        ).toggle()        
                                

class PlaylistView extends Backbone.View

    el: $('#playlist')

    template: Handlebars.compile($('#playlist_tmpl').html()),

    events: 
        "click #playlist .song": "togglePlaying"

    initialize: ->
        _.bindAll @, 'updatePlaylist'

        @model.playlist.bind 'add', @updatePlaylist
        @model.playlist.bind 'reset', @updatePlaylist
    
    togglePlaying: (evt) ->
        id = + $.attr evt.currentTarget, 'data-id'
        
        if @model.get('current_track') is id
            @model.pause()
        else
            @model.play id
        
    artistPlaylistCount: (artist, start_from) ->        
        count = 0

        for track in @model.playlist.models[start_from..]
            count++ if track.get('artist') is artist

        count


    updatePlaylist: ->
        console.log('updating playlist')

        merge_rows = 0
                
        playlist = @model.playlist.toJSON()
        
        for track in playlist
            track.artist_image = chromus.plugins.lastfm.image 
                artist: track.artist
            track.previous = playlist[_i-1]
            track.next = playlist[_i+1]

            if not track.previous or track.previous.artist isnt track.artist
                track.artist_playlist_count = @artistPlaylistCount(track.artist, _i)
        
        pane = @el.data('jsp')

        view = 
            playlist: playlist        

        model = @model
            
        helpers =
            is_previous: (fn) ->
                if not @previous or @previous.artist isnt @artist then fn(@)

            is_next: (fn) ->                
                if not @next or @next.artist isnt @artist then fn(@)

            title: (fn) -> 
                if @type is 'artist'
                    "Loading..."
                else
                    @song or @name

            more_then_two: (fn) -> if @artist_playlist_count > 2 then fn(@)

            is_current: (fn) -> if @id is model.get('current_track') then fn(@)


        helpers = _.defaults helpers, Handlebars.helpers        

        if pane
            pane.getContentPane()
                .html @template view, helpers: helpers
            
            pane.reinitialise()
        else
            @el.html @template view, helpers: helpers
                            
            @el.jScrollPane
                maintainPosition: true        

        $('#playlist').css visibility:'visible'


class App extends Backbone.View
    initialize: ->        
        @model = new Player()

        @playlist = new PlaylistView { model:@model }
        @controls = new Controls { model:@model }
        @track_info = new TrackInfo { model:@model }
        @menu = new Menu { model:@model }
        
    start: ->        
        browser.postMessage method:'getPlaylist'
        browser.postMessage method:'getSettings'

@app = new App()


$ -> browser.onReady -> app.start()