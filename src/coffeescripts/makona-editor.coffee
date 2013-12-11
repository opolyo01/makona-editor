`/** @jsx React.DOM */`

require("script!../../bower_components/jquery/jquery.min.js")

#require("script!../../bower_components/jquery-ui/ui/minified/jquery-ui.min.js")
require("script!../../bower_components/jquery-ui/ui/minified/jquery.ui.core.min.js")
require("script!../../bower_components/jquery-ui/ui/minified/jquery.ui.widget.min.js")
require("script!../../bower_components/jquery-ui/ui/minified/jquery.ui.mouse.min.js")
require("script!../../bower_components/jquery-ui/ui/minified/jquery.ui.position.min.js")
require("script!../../bower_components/jquery-ui/ui/minified/jquery.ui.draggable.min.js")
require("script!../../bower_components/jquery-ui/ui/minified/jquery.ui.droppable.min.js")
require("script!../../bower_components/jquery-ui/ui/minified/jquery.ui.sortable.min.js")

# Makes sortable work on touch devices
require("script!../../vendor/jquery-ui-touch-punch.min.js")

# Used to put caret at the end of the textarea
require("script!../../vendor/jquery-caret.min.js")

require("script!../../bower_components/lodash/dist/lodash.compat.min.js")
require("script!../../bower_components/react/react-with-addons.min.js")


# Makona will be exposed on window, and be the main entry point to the editor from the outside
class Makona
  constructor: (opts) ->
    # Delete the textarea node, save the name, and replace it with a div. The Raw component will
    # create a textarea with that name.
    opts.node_name = $("##{opts.node_id}").attr("name")
    $("##{opts.node_id}").replaceWith("<div id='#{opts.node_id}' class='makona-editor'></div>")
    React.renderComponent (MakonaEditor {opts: opts}), document.getElementById(opts.node_id)

Blocks = require("./blocks")

MakonaEditor = React.createClass
  loadBlocksFromServer: () ->
    $.ajax
      url: this.props.opts.url
      success: (blocks) =>
        blocks = blocks.map (block) -> $.extend({}, {mode: 'preview'}, block)
        this.setState({blocks: blocks})

  getInitialState: () -> blocks: []

  componentWillMount: () ->
    this.loadBlocksFromServer()

  componentDidMount: () ->
    $(this.getDOMNode()).on "addRow", (e, position, block) =>
      e.preventDefault()
      this.handleAddRow(position, block)

  handleAddRow: (position, block) ->
    block.id = _.max(this.state.blocks, "id").id + 1
    block.position = position + 0.5
    newBlocks = this.resortBlocks(this.state.blocks.concat(block))
    this.setState({blocks: newBlocks})

  handleChange: (changedBlock, replaceFlag) ->
    newBlocks = this.state.blocks.map (block) ->
      block.data = changedBlock.data if block.id is changedBlock.id
      block
    if replaceFlag is true
      this.replaceState({blocks: []})
      this.replaceState({blocks: newBlocks})
    else
      this.setState({blocks: newBlocks})

  handleDelete: (id) ->
    newBlocks = _.reject this.state.blocks, (block) -> block.id is id
    this.replaceState({blocks: newBlocks})

  handleReorder: (sortedBlocks) ->
    this.replaceState({blocks: []})
    this.replaceState({blocks: sortedBlocks})

  # To add a block we add at position x+0.5, then sort by position, and loop through and reset the position counter
  resortBlocks: (blocks) ->
    i = 0
    _.sortBy(blocks, "position").map (b, i) -> (b.position = i++; b)

  render: ->
    `(
      <div className='mk-editor'>
        <MakonaSortableList
          blocks={this.state.blocks}
          opts={this.props.opts}
          handleReorder={this.handleReorder}
          handleChange={this.handleChange}
          handleDelete={this.handleDelete}
        />
        <hr />
        {/*<MakonaPreviewList blocks={this.state.blocks} opts={this.props.opts} /> */}
        <hr />
        <MakonaRaw blocks={this.state.blocks} opts={this.props.opts}/>
      </div>
    )`


MakonaSortableList = React.createClass
  componentDidMount: () ->
    $(this.refs.sortable.getDOMNode()).sortable
      containment: "parent"
      handle: ".handle"
      update: (event, ui) =>
        sortedBlocks = []
        $(this.refs.sortable.getDOMNode()).find(">li").map (i, el) =>
          theBlock = _.findWhere(this.props.blocks, {id: parseInt(el.id,10)})
          theBlock.position = i
          sortedBlocks.push(theBlock)
        this.props.handleReorder(sortedBlocks)

  handleDelete: (id, e) ->
    if confirm("Are you sure you want to delete this block?")
      this.props.handleDelete(id)

  handleEdit: (id, e) ->
    block = Blocks.blockFromId(this.props.blocks, id)
    block = $.extend(block, {mode: 'edit'})
    this.props.handleChange(block)
    # This isnt very React-y
    setTimeout =>
      $(this.refs["editor"+id].getDOMNode()).find("textarea").focus().caretToEnd()
    , 100

  handlePreview: (id, e) ->
    block = Blocks.blockFromId(this.props.blocks, id)
    block = $.extend(block, {mode: 'preview'})
    this.props.handleChange(block)

  editClasses: (id) ->
    block = Blocks.blockFromId(this.props.blocks, id)
    cx = React.addons.classSet
    editClasses = cx
      "mk-editor": true
      "mk-mode-edit": (block.mode == 'edit')

  previewClasses: (id) ->
    block = Blocks.blockFromId(this.props.blocks, id)
    cx = React.addons.classSet
    editClasses = cx
      "mk-previewer": true
      "mk-mode-preview": !block.mode? || (block.mode == 'preview')

  editControls: (block) ->
    editClasses = React.addons.classSet
      "hide": (block.mode is 'edit' || !Blocks.blockTypeFromRegistry(block.type).editable)
    previewClasses = React.addons.classSet
      "hide": (block.mode is 'preview' || !Blocks.blockTypeFromRegistry(block.type).editable)
    `(
      <div className="mk-edit-controls">
        <a href="javascript:void(0);" className={editClasses} onClick={this.handleEdit.bind(this, block.id)}><div className="icon" data-icon="&#x6b;"></div></a>
        <a href="javascript:void(0);" className={previewClasses} onClick={this.handlePreview.bind(this, block.id)}><div className="icon" data-icon="&#x6c;"></div></a>
        {(this.props.blocks.length > 1) ?
          <a href="javascript:void(0);" onClick={this.handleDelete.bind(this, block.id)}><div className="icon" data-icon="&#xe019;"></div></a> : ""
        }
      </div>
    )`

  render: ->
    `(
      <ol className="mk-edit" ref='sortable'>
        {this.props.blocks.map(
          function(block){
            return (
              <li className="Bfc" id={block.id} key={"ks"+block.id} data-position={block.position} >
                <div className={"mk-block mk-block-"+block.type}>
                  <div className={this.editClasses(block.id)} ref={"editor"+block.id} >
                    {Blocks.blockTypeFromRegistry(block.type).editable ? <MakonaEditorRow block={block} opts={this.props.opts} handleChange={this.props.handleChange} /> : ""}
                  </div>
                  <div className={this.previewClasses(block.id)} ref={"preview"+block.id} onDoubleClick={this.handleEdit.bind(this, block.id)}>
                    <MakonaPreviewerRow block={block} opts={this.props.opts} />
                  </div>
                </div>
                <div className="mk-block-controls">
                  <div className="handle icon" data-icon="&#x61;"></div>
                  {this.editControls(block)}
                </div>
                <MakonaPlusRow block={block} opts={this.props.opts} />
              </li>
            )
          }.bind(this)
        )}
      </ol>
    )`

MakonaEditorRow = React.createClass
  render: ->
    `Blocks.blockTypeFromRegistry(this.props.block.type).editorClass({block: this.props.block, opts: this.props.opts, handleChange: this.props.handleChange})`

MakonaPreviewerRow = React.createClass
  render: ->
    `Blocks.blockTypeFromRegistry(this.props.block.type).previewClass({block: this.props.block, opts: this.props.opts})`

MakonaPlusRow = React.createClass
  getInitialState: () ->
    hideLinks: true

  addRow: (e, reactid) ->
    type = $("[data-reactid='#{reactid}'").data("type")
    newBlock = Blocks.newBlock(type)
    $(this.getDOMNode()).trigger("addRow", [this.props.block.position, newBlock])
    this.setState {'hideLinks': true}

  toggleLinks: () ->
    this.setState {'hideLinks': !this.state.hideLinks}

  blockTypeLink: (block) ->
    `<a href="javascript: void(0);" onClick={this.addRow} data-type={block.type}><div className="icon" data-icon={block.icon}></div><div>{block.displayName}</div></a>`

  blockTypes: () ->
    _.map Blocks.createableBlockTypes(), (block) =>
      @blockTypeLink block

  render: ->
    classes = React.addons.classSet
      'mk-plus-links': true
      'hide': this.state.hideLinks

    `(
      <div className="mk-plus">
        <a className="mk-plus-add" href="javascript:void(0);" onClick={this.toggleLinks}>Add Block</a>
        <div className={classes}>
          {this.blockTypes()}
        </div>
      </div>
    )`

MakonaRaw = React.createClass
  render: ->
    `<textarea className="mk-raw" name={this.props.opts.node_name} value={JSON.stringify(this.props.blocks, null, 2)}></textarea>`


# Not sure we need this
MakonaPreviewList = React.createClass
  componentDidMount: () ->
    this.renderRows()

  componentDidUpdate: () ->
    this.renderRows()

  renderRows: ->
    this.props.blocks.map (block) ->
     `React.renderComponent(<MakonaPreviewerRow block={block} opts={this.props.opts} />, this.refs['preview' + block.id].getDOMNode())`
    , this

  render: ->
    `(
      <ol className="mk-preview" ref='preview'>
        {this.props.blocks.map(
          function(block){
            return (
              <li key={"kp"+block.id} data-position={block.position}>
                <div className={"mk-block mk-block-"+block.type} ref={"preview"+block.id}>
                  *Row gets rendered in here*
                </div>
              </li>
            )
          }.bind(this)
        )}
      </ol>
    )`

module.exports = window.Makona = Makona