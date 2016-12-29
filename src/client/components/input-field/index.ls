Ractive.components['input-field'] = Ractive.extend do
    template: RACTIVE_PREPARSE('index.pug')
    isolated: yes
    onrender: ->
        number-units = """
            dakika saniye saat
            kg gr
            """

        if @get('unit').to-lower-case! in number-units.split ' '
            @set \type, \number

        if @get('type') is \number
            input = $ @find \input
            input.on \focus, (ev) ->
                $ this .on \mousewheel.disableScroll, (ev) ->
                    $ this .blur!

    data: ->
        type: \number