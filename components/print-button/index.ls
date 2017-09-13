require! 'aea':{sleep}
require! 'dcs/browser': {RactiveActor}


Ractive.components['print-button'] = Ractive.extend do
    template: RACTIVE_PREPARSE('index.pug')
    isolated: yes
    onrender: ->
        @actor = new RactiveActor this, name: 'print button'

        @on do
            _preparePrint: (ctx) ->
                const c = ctx.getParent yes
                c.refire = yes
                err, res <~ @fire \print, c
                if err
                    @actor.send 'app.log.err', do
                        message: {"Error while printing": err}
                    return

                printWindow = window.open('', '', 'scrollbars=yes, resizable=yes, width=800, height=500')
                unless printWindow
                    return alert 'Your browser does not let me open a window!'

                # TODO: add stylesheets in place
                #a = document.styleSheets
                #debugger

                doc = if res.html
                    res.html
                else
                    """
                    <html  moznomarginboxes mozdisallowselectionprint>
                        <head>
                            <link rel="stylesheet" href="css/vendor.css">
                            <style>
                                @page {
                                    margin: 0; /* in order to disable page header and footer */
                                }
                                .no-print {
                                    display: none;
                                }
                                \#page-container {
                                    margin: 15mm;
                                }

                                /* custom style */
                                #{res.style}
                            </style>
                        </head>
                        <body>
                            <div id="page-container">
                                #{res.body}
                            </div>
                        </body>
                        <script>window.print(); window.close()</script>
                    </html>
                    """
                printWindow.document.writeln doc
                printWindow.document.close!
