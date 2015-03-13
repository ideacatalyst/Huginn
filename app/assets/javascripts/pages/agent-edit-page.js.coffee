class @AgentEditPage
  constructor: ->
    $("#agent_source_ids").on "change", @showEventDescriptions
    @showCorrectRegionsOnStartup()

    # The type selector is only available on the new agent form.
    if $("#agent_type").length
      $("#agent_type").on "change", => @handleTypeChange(false)
      @handleTypeChange(true)

    unless $('agent-dry-run-button').prop('disabled')
      @enableDryRunButton()

  handleTypeChange: (firstTime) ->
    $(".event-descriptions").html("").hide()
    type = $('#agent_type').val()

    if type == 'Agent'
      $(".agent-settings").hide()
      $(".description").hide()
    else
      $(".agent-settings").show()
      $("#agent-spinner").fadeIn()
      $(".model-errors").hide() unless firstTime
      $.getJSON "/agents/type_details", { type: type }, (json) =>
        if json.can_be_scheduled
          if firstTime
            @showSchedule()
          else
            @showSchedule(json.default_schedule)
        else
          @hideSchedule()

        if json.can_receive_events
          @showLinks()
        else
          @hideLinks()

        if json.can_control_other_agents
          @showControlLinks()
        else
          @hideControlLinks()

        if json.can_create_events
          @showEventCreation()
        else
          @hideEventCreation()

        $(".description").show().html(json.description_html) if json.description_html?

        unless firstTime
          $('.oauthable-form').html(json.oauthable) if json.oauthable?
          $('.agent-options').html(json.form_options) if json.form_options?
          window.jsonEditor = setupJsonEditor()[0]

        if json.can_dry_run
          @enableDryRunButton()
        else
          @disableDryRunButton()

        window.initializeFormCompletable()

        $("#agent-spinner").stop(true, true).fadeOut();

  hideSchedule: ->
    $(".schedule-region .can-be-scheduled").hide()
    $(".schedule-region .cannot-be-scheduled").show()

  showSchedule: (defaultSchedule = null) ->
    if defaultSchedule?
      $(".schedule-region select").val(defaultSchedule).change()
    $(".schedule-region .can-be-scheduled").show()
    $(".schedule-region .cannot-be-scheduled").hide()

  hideLinks: ->
    $(".link-region .select2-container").hide()
    $(".link-region .propagate-immediately").hide()
    $(".link-region .cannot-receive-events").show()

  showLinks: ->
    $(".link-region .select2-container").show()
    $(".link-region .propagate-immediately").show()
    $(".link-region .cannot-receive-events").hide()
    @showEventDescriptions()

  hideControlLinks: ->
    $(".control-link-region").hide()

  showControlLinks: ->
    $(".control-link-region").show()

  hideEventCreation: ->
    $(".event-related-region").hide()

  showEventCreation: ->
    $(".event-related-region").show()

  showEventDescriptions: ->
    if $("#agent_source_ids").val()
      $.getJSON "/agents/event_descriptions", { ids: $("#agent_source_ids").val().join(",") }, (json) =>
        if json.description_html?
          $(".event-descriptions").show().html(json.description_html)
        else
          $(".event-descriptions").hide()
    else
      $(".event-descriptions").html("").hide()

  showCorrectRegionsOnStartup: ->
    if $(".schedule-region")
      if $(".schedule-region").data("can-be-scheduled") == true
        @showSchedule()
      else
        @hideSchedule()

    if $(".link-region")
      if $(".link-region").data("can-receive-events") == true
        @showLinks()
      else
        @hideLinks()

    if $(".control-link-region")
      if $(".control-link-region").data("can-control-other-agents") == true
        @showControlLinks()
      else
        @hideControlLinks()

    if $(".event-related-region")
      if $(".event-related-region").data("can-create-events") == true
        @showEventCreation()
      else
        @hideEventCreation()

  enableDryRunButton: ->
    $(".agent-dry-run-button").prop('disabled', false).off().on "click", @invokeDryRun

  disableDryRunButton: ->
    $(".agent-dry-run-button").prop('disabled', true)

  invokeDryRun: (e) ->
    e.preventDefault()
    $(".agent-dry-run-button").prop('disabled', true)
    $('body').css(cursor: 'progress')
    $.ajax type: 'POST', url: $(".agent-dry-run-button").data('action-url'), dataType: 'json', data: $(@form).serialize()
      .always =>
        $("body").css(cursor: 'auto')
      .done (json) =>
        $("body").append """
          <div class="modal fade" tabindex="-1" id='dynamic-modal' role="dialog" aria-labelledby="dynamic-modal-label" aria-hidden="true">
            <div class="modal-dialog modal-lg">
              <div class="modal-content">
                <div class="modal-header">
                  <button type="button" class="close" data-dismiss="modal"><span aria-hidden="true">&times;</span><span class="sr-only">Close</span></button>
                  <h4 class="modal-title" id="dynamic-modal-label"></h4>
                </div>
                <div class="modal-body">
                  <h5>Log</h5>
                  <pre class="agent-dry-run-log"></pre>
                  <h5>Events</h5>
                  <pre class="agent-dry-run-events"></pre>
                  <h5>Memory</h5>
                  <pre class="agent-dry-run-memory"></pre>
                </div>
              </div>
            </div>
          </div>
        """
        $('#dynamic-modal').find('.modal-title').text "Dry Run Results"
        $('#dynamic-modal').find('.modal-body').
          find('.agent-dry-run-log').text(json.log).end().
          find('.agent-dry-run-events').text(json.events).end().
          find('.agent-dry-run-memory').text(json.memory)
        $('#dynamic-modal').modal('show').on 'hidden.bs.modal', ->
          $('#dynamic-modal').remove()
          $(".agent-dry-run-button").prop('disabled', false)
      .fail (xhr, status, error) =>
        alert('Error: ' + error)
        $(".agent-dry-run-button").prop('disabled', false)

$ ->
  Utils.registerPage(AgentEditPage, forPathsMatching: /^agents/)
