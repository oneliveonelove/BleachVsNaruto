/*
 * Copyright (C) 2021-2024, 5DPLAY Game Studio
 * All rights reserved.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

package net.play5d.game.bvn.stage {
import com.greensock.TweenLite;
import com.greensock.easing.Back;

import flash.display.Bitmap;
import flash.display.DisplayObject;
import flash.display.InteractiveObject;
import flash.display.Sprite;
import flash.display.SimpleButton;
import flash.events.Event;
import flash.events.MouseEvent;
import flash.events.TouchEvent;
import flash.geom.Point;
import flash.utils.Dictionary;
import flash.utils.setTimeout;

import net.play5d.game.bvn.GameConfig;
import net.play5d.game.bvn.MainGame;
import net.play5d.game.bvn.ctrler.AssetManager;
import net.play5d.game.bvn.ctrler.GameLogic;
import net.play5d.game.bvn.ctrler.GameRender;
import net.play5d.game.bvn.ctrler.SoundCtrl;
import net.play5d.game.bvn.ctrler.StateCtrl;
import net.play5d.game.bvn.data.AssisterModel;
import net.play5d.game.bvn.data.FighterModel;
import net.play5d.game.bvn.data.vos.FighterVO;
import net.play5d.game.bvn.data.GameData;
import net.play5d.game.bvn.data.GameMode;
import net.play5d.game.bvn.data.MessionModel;
import net.play5d.game.bvn.data.vos.SelectCharListConfigVO;
import net.play5d.game.bvn.data.vos.SelectCharListItemVO;
import net.play5d.game.bvn.data.vos.SelectStageConfigVO;
import net.play5d.game.bvn.data.vos.SelectVO;
import net.play5d.game.bvn.debug.Debugger;
import net.play5d.game.bvn.events.GameEvent;
import net.play5d.game.bvn.input.GameInputType;
import net.play5d.game.bvn.input.GameInputer;
import net.play5d.game.bvn.ui.GameUI;
import net.play5d.game.bvn.ui.select.SelectMapUI;
import net.play5d.game.bvn.ui.select.SelectFighterItem;
import net.play5d.game.bvn.ui.select.SelectUIFactory;
import net.play5d.game.bvn.ui.select.SelectedFighterGroup;
import net.play5d.game.bvn.ui.select.SelecterItemUI;
import net.play5d.game.bvn.utils.KeyBoarder;
import net.play5d.game.bvn.utils.ResUtils;
import net.play5d.kyo.stage.IStage;
import net.play5d.kyo.utils.ArrayMap;
import net.play5d.kyo.utils.KyoRandom;

public class SelectFighterStage implements IStage {
    include '../../../../../../include/_INCLUDE_.as';

    private static const SELECT_STATE_FIGHTER:int = 0;
    private static const SELECT_STATE_ASSIST:int  = 1;
    private static const SELECT_STATE_MAP:int     = 2;
    public static var AUTO_FINISH:Boolean = true;
    public static var LOCAL_SELECT_PLAYER:int = 0;

    public function SelectFighterStage() {
    }
    private var _selectState:int;
    private var _ui:$select$MC_stgSelect;
    private var _fighterListUI:Sprite;
    private var _config:SelectStageConfigVO;
    private var _curListConfig:SelectCharListConfigVO;
    private var _itemObj:Object;
    private var _p1Slt:SelecterItemUI;
    private var _p2Slt:SelecterItemUI;
    private var _p1SelectedGroup:SelectedFighterGroup;
    private var _p2SelectedGroup:SelectedFighterGroup;
    private var _mapSelectUI:SelectMapUI;
    private var _curStep:int = 0;
    private var _tweenTime:int = 500;
    private var _twoPlayerSelectFin:Boolean;  //Ã¨Â§Â£Ã¥â€ Â³Ã¤Â¸Â¤Ã§Å½Â©Ã¥Â®Â¶Ã¥ÂÅ’Ã¦â€”Â¶Ã©â‚¬â€°Ã¤ÂºÂº
    [Embed(source='/../assets/cancel.png')]
    private var _backMenuPicClass:Class;
    private var _backMenuBtn:Sprite;
    
    // Pagination state
    private static const SELECT_PAGE_STEP:Number = 493;
    private static const SELECT_PAGE_ROWS:int = 7;
    private var _pageIndex:int = 0;
    private var _pageChanging:Boolean = false;
    private var _pageCount:int = 1;
    /**
     * *******************************************************************************************************************************************************
     */

                //		private var _moreFighterItems:Vector.<SelectFighterItem>;
    private var _moreFighterMap:Dictionary = new Dictionary();
    private var _moreFighterCache:Object   = {};

    /**
     * Ã¦ËœÂ¾Ã§Â¤ÂºÃ¥Â¯Â¹Ã¨Â±Â¡
     */
    public function get display():DisplayObject {
        return _ui;
    }

    public function get p1SelectFinish():Boolean {
        return _p1Slt && _p1Slt.selectFinish();
    }

    private function initPageBtn():void {
        var names:Array = ["bu2", "bu4", "bu1", "bu3"];
        var handlers:Array = [pageUpHandler, pageUpHandler, pageDownHandler, pageDownHandler];

        for (var i:int = 0; i < names.length; i++) {
            var btn:InteractiveObject = _ui.getChildByName(names[i]) as InteractiveObject;
            if (btn) {
                _ui.addChild(btn); // Bring to front
                if (GameConfig.TOUCH_MODE) {
                    btn.addEventListener(TouchEvent.TOUCH_TAP, handlers[i]);
                } else {
                    btn.addEventListener(MouseEvent.CLICK, handlers[i]);
                }
                btn.visible = true;
                trace("[SelectFighterStage] Found and initialized button: " + names[i]);
            } else {
                trace("[SelectFighterStage] Button not found in UI: " + names[i]);
            }
        }
    }

    private function removePageBtn():void {
        var names:Array = ["bu2", "bu4", "bu1", "bu3"];
        var handlers:Array = [pageUpHandler, pageUpHandler, pageDownHandler, pageDownHandler];

        for (var i:int = 0; i < names.length; i++) {
            var btn:InteractiveObject = _ui.getChildByName(names[i]) as InteractiveObject;
            if (btn) {
                btn.removeEventListener(TouchEvent.TOUCH_TAP, handlers[i]);
                btn.removeEventListener(MouseEvent.CLICK, handlers[i]);
                btn.visible = false;
            }
        }
    }

    public function get p2SelectFinish():Boolean {
        return _p2Slt && _p2Slt.selectFinish();
    }

    /**
     * Ã¦Å¾â€žÃ¥Â»Âº
     */
    public function build():void {
        _ui            = ResUtils.I.createDisplayObject(ResUtils.swfLib.select, ResUtils.SELECT);
        _fighterListUI = new Sprite();

        _ui.addChild(_fighterListUI);

        _config = GameData.I.config.select_config;

        GameRender.add(render);
        GameInputer.focus();
        GameInputer.enabled = false;

        nextStep();

        SoundCtrl.I.BGM(AssetManager.I.getSound('select'));

        StateCtrl.I.clearTrans();

        KeyBoarder.focus();

        GameEvent.dispatchEvent(GameEvent.SELECT_FIGHTER);


    }

    public function setSelect(player:int, selects:Array):void {
        var selt:SelecterItemUI = player == 1 ? _p1Slt : _p2Slt;
        selt.setCurrentSelect(selects);
        selt.removeSelecter();
        SoundCtrl.I.sndConfrim();
    }

    public function nextStep():void {
        switch (_curStep) {
        case 0: //Ã¥Ë†ÂÃ¥Â§â€¹Ã¥Å’â€“
            initFighter();
            _curStep = 1;
            break;
        case 1:
            //Ã¤Â¸Â»Ã¨Â§â€™Ã©â‚¬â€°Ã¦â€¹Â©Ã¥Â®Å’Ã¦Ë†Â
            if (GameMode.isVsCPU()) {
                _p1Slt.removeSelecter();
                _p1Slt.enabled = false;
                initSelecterP2();
                _p2Slt.inputType = GameInputType.P1;
                _curStep         = 2;
            }
            else {
                //Ã¥Ë†ÂÃ¥Â§â€¹Ã¥Å’â€“Ã¨Â¾â€¦Ã¥Å Â©

                fadOutList(initAssist);

//						initAssist();
//						selectFinish();
                _curStep = 3;
            }

            break;
        case 2:
            //Ã¥Ë†ÂÃ¥Â§â€¹Ã¥Å’â€“Ã¨Â¾â€¦Ã¥Å Â©
//					initAssist();
            fadOutList(initAssist);
            _curStep = 3;
            break;
        case 3:
            //Ã¤Â¸Â»Ã¨Â§â€™Ã¨Â¾â€¦Ã¥Å Â©Ã©â‚¬â€°Ã¦â€¹Â©Ã¥Â®Å’Ã¦Ë†Â
            if (GameMode.isVsCPU()) {
                _p1Slt.removeSelecter();
                _p1Slt.enabled = false;
                initSelecterP2();
                _p2Slt.inputType = GameInputType.P1;
                _curStep         = 4;
            }
            else {

                if (GameMode.isVsCPU() || GameMode.isVsPeople()) {
                    //Ã©â‚¬â€°Ã¦â€¹Â©Ã¥Å“Â°Ã¥â€ºÂ¾

                    fadOutList(initMap);

//							initMap();
                    _curStep = 5;
                }
                else {

                    if (GameMode.isArcade()) {
                        //Ã¥Â¼â‚¬Ã¥Â§â€¹Ã¨Â¿ÂÃ¨Â¡Å’Ã¨Â¿â€¡Ã¥â€¦Â³Ã¦Â¨Â¡Ã¥Â¼Â
                        startAcradeGame();
                    }

                    if (GameMode.currentMode == GameMode.MUSOU_ARCADE) {
                        //Ã¥Â¼â‚¬Ã¥Â§â€¹Ã¨Â¿ÂÃ¨Â¡Å’Ã¨Â¿â€¡Ã¥â€¦Â³Ã¦Â¨Â¡Ã¥Â¼Â
                        startMosouGame();
                    }

                }

            }
            break;
        case 4:
            //Ã©â‚¬â€°Ã¦â€¹Â©Ã¥Å“Â°Ã¥â€ºÂ¾
            _curStep = 5;
            fadOutList(initMap);
//					initMap();
            break;
        case 5:
            selectFinish();
            break;
        }

    }

    public function goLoadGame():void {
        trace("Ã¥Â¼â‚¬Ã¥Â§â€¹Ã¦Â¸Â¸Ã¦Ë†Â");
        StateCtrl.I.transIn(MainGame.I.loadGame);
    }

    /**
     * Ã§Â¨ÂÃ¥ÂÅ½Ã¦Å¾â€žÃ¥Â»Âº
     */
    public function afterBuild():void {
    }

    /**
     * Ã©â€â‚¬Ã¦Â¯Â
     * @param back Ã¥â€ºÅ¾Ã¨Â°Æ’Ã¥â€¡Â½Ã¦â€¢Â°
     */
    public function destroy(back:Function = null):void {
        clear();
        GameRender.remove(render);
        GameInputer.enabled = false;
        SoundCtrl.I.BGM(null);
        GameUI.closeConfrim();

        if (_backMenuBtn) {
            _backMenuBtn.removeEventListener(TouchEvent.TOUCH_TAP, backMenuHandler);
            _backMenuBtn.removeEventListener(MouseEvent.CLICK, backMenuHandler);
            _backMenuBtn.visible = false;
        }
    }

    private function initBackBtn():void {
        if (!_backMenuBtn) {
            _backMenuBtn         = new Sprite();
            var btnBitmap:Bitmap = new _backMenuPicClass();
            btnBitmap.width      = 100;
            btnBitmap.smoothing  = true;
            btnBitmap.scaleY     = btnBitmap.scaleX;
            _backMenuBtn.addChild(btnBitmap);

            if (GameConfig.TOUCH_MODE) {
                _backMenuBtn.addEventListener(TouchEvent.TOUCH_TAP, backMenuHandler);
            }
            else {
                _backMenuBtn.addEventListener(MouseEvent.CLICK, backMenuHandler);
            }
        }
        _ui.addChild(_backMenuBtn);
    }

    private function initFighter():void {
        trace('Ã¥Ë†ÂÃ¥Â§â€¹Ã¥Å’â€“Ã©â‚¬â€°Ã¤ÂºÂº');
        clear();
        _selectState = SELECT_STATE_FIGHTER;
        buildList(_config.charList);

        GameData.I.p1Select = new SelectVO();
        if (GameMode.isVsPeople() || GameMode.isVsCPU()) {
            GameData.I.p2Select = new SelectVO();
        }

        GameInputer.enabled = false;
        setTimeout(initSelecter, _tweenTime);
        // Ã©â€ºÂ¨Ã¥â€¦Â®Ã¥Â®Å¡Ã¥Ë†Â¶Ã¥Ë†Â Ã©â„¢Â¤
			initPageBtn();
        if (GameConfig.TOUCH_MODE) {
            initBackBtn();
        }
//			initSelecter();
    }

    //Ã¥Ë†ÂÃ¥Â§â€¹Ã¥Å’â€“Ã¨Â¾â€¦Ã¥Å Â©
    private function initAssist():void {
        trace('Ã¥Ë†ÂÃ¥Â§â€¹Ã¥Å’â€“Ã¨Â¾â€¦Ã¥Å Â©');
        clear();
        _selectState = SELECT_STATE_ASSIST;
        buildList(_config.assistList);
        GameInputer.enabled = false;
        // Ã©â€ºÂ¨Ã¥â€¦Â®Ã¥Â®Å¡Ã¥Ë†Â¶Ã¥Ë†Â Ã©â„¢Â¤
			initPageBtn();
        if (GameConfig.TOUCH_MODE) {
            initBackBtn();
        }
        setTimeout(initSelecter, _tweenTime);
    }

    private function fadOutList(back:Function = null):void {

        GameInputer.enabled = false;

        var outX:Number = GameConfig.GAME_SIZE.x / 2 - 30;
        var outY:Number = GameConfig.GAME_SIZE.y / 2 - 30;

        for each(var i:SelectFighterItem in _itemObj) {
            var delay:Number = Math.random() * 0.1;
            TweenLite.to(i.ui, 0.2, {x: outX, y: outY, scaleX: 0, scaleY: 0, delay: delay});
        }

        for each(var f:ArrayMap in _moreFighterMap) {
            if (!f) {
                continue;
            }
            for (var j:int = 0; j < f.length; j++) {
                var si:SelectFighterItem = f.getItemByIndex(j);
                si.destory();
            }
            _moreFighterMap[f] = null;
        }

        if (back != null) {
            TweenLite.delayedCall(0.3, back);
        }
    }

    private function clear():void {
        if (_itemObj) {
            for each(var i:SelectFighterItem in _itemObj) {
                i.removeEventListener(MouseEvent.MOUSE_OVER, selectFighterMouseHandler);
                i.removeEventListener(MouseEvent.CLICK, selectFighterMouseHandler);
                i.removeEventListener(TouchEvent.TOUCH_TAP, selectFighterTouchHandler);
                i.destory();
            }
            _itemObj = null;
        }

        if (_p1Slt) {
            _p1Slt.destory();
            _p1Slt = null;
        }

        if (_p2Slt) {
            _p2Slt.destory();
            _p2Slt = null;
        }

        if (_mapSelectUI) {
            _mapSelectUI.destory();
            _mapSelectUI = null;
        }

        if (_p1SelectedGroup) {
            _p1SelectedGroup.destory();
            _p1SelectedGroup = null;
        }

        if (_p2SelectedGroup) {
            _p2SelectedGroup.destory();
            _p2SelectedGroup = null;
        }

			removePageBtn();

    }

    private function buildList(list:SelectCharListConfigVO):void {
        _fighterListUI.y = 0;
        _pageIndex = 0;
        _pageChanging = false;
        
        var vCount:int = list.VCount;
        _pageCount = Math.ceil(vCount / SELECT_PAGE_ROWS);

        var startX:Number = _config.x + _config.left;
        var startY:Number = _config.y + _config.top;
        var gapX:Number   = list.HCount > 1 ? (
                                                      _config.width - _config.unitSize.x - _config.left - _config.right
                                              ) / (
                                                      list.HCount - 1
                                              ) : 0;
        var gapY:Number   = list.VCount > 1 ? (
                                                      _config.height - _config.unitSize.y - _config.top - _config.bottom
                                              ) / (
                                                      list.VCount - 1
                                              ) : 0;

        var charList:Array = list.list;
        _curListConfig     = list;

        _itemObj = {};

        var initX:Number = GameConfig.GAME_SIZE.x / 2 - 30;
        var initY:Number = GameConfig.GAME_SIZE.y / 2 - 30;

        for (var i:int; i < charList.length; i++) {
            var s:SelectCharListItemVO = charList[i];
            var sf:SelectFighterItem   = addFighterItem(s);
            if (!sf) {
                continue;
            }

            var tx:Number = startX + (gapX * sf.selectData.x);
            var ty:Number = startY + (gapY * sf.selectData.y);
            if (sf.selectData.offset) {
                tx += sf.selectData.offset.x;
                ty += sf.selectData.offset.y;
            }

            sf.ui.scaleX = 0;
            sf.ui.scaleY = 0;
            sf.ui.x      = initX;
            sf.ui.y      = initY;

            var delay:Number = Math.random() * (_tweenTime - 300) / 1000;

            TweenLite.to(sf.ui, 0.3,
                         {x: tx, y: ty, delay: delay, scaleX: 1, scaleY: 1, ease: Back.easeOut}
            );
        }
    }

    private function addFighterItem(sv:SelectCharListItemVO):SelectFighterItem {
        if (!sv.fighterID) {
            return null;
        }

        var fv:FighterVO = _selectState == SELECT_STATE_ASSIST ? AssisterModel.I.getAssister(sv.fighterID) :
                           FighterModel.I.getFighter(sv.fighterID);
        if (!fv) {
            Debugger.log('SelectFighterStage.addFighterItem :: Ã¦Å“ÂªÃ¦â€°Â¾Ã¥Ë†Â°Ã¨Â§â€™Ã¨â€°Â²Ã¦â€¢Â°Ã¦ÂÂ®Ã¯Â¼Å¡' + sv.fighterID);
            return null;
        }

        var unitWidth:Number  = 60;
        var unitHeight:Number = 60;

        var si:SelectFighterItem = new SelectFighterItem(fv, sv);

        if (GameConfig.TOUCH_MODE) {
            si.addEventListener(TouchEvent.TOUCH_TAP, selectFighterTouchHandler);
        }
        else {
            si.addEventListener(MouseEvent.MOUSE_OVER, selectFighterMouseHandler);
            si.addEventListener(MouseEvent.CLICK, selectFighterMouseHandler);
        }

        _fighterListUI.addChild(si.ui);

//			si.ui.x = sv.x * (unitWidth + _config.itemGap.x);
//			si.ui.y = sv.y * (unitHeight + _config.itemGap.y);

        _itemObj[sv.x + ',' + sv.y] = si;

        return si;
    }

    private function selectFighterMouseHandler(type:String, target:SelectFighterItem):void {
        if (!target || (
                !target.selectData && !target.isMore
        )) {
            return;
        }

        switch (type) {
        case MouseEvent.MOUSE_OVER:
            doHover(target);
            break;
        case MouseEvent.CLICK:
            doSelect(target);
            break;
        }
    }

    private function selectFighterTouchHandler(type:String, target:SelectFighterItem):void {
        if (_pageChanging) {
            return;
        }
        if (!target || (
                !target.selectData && !target.isMore
        )) {
            return;
        }

        var curSlt:SelecterItemUI = null;

        if (_p1Slt && _p1Slt.enabled) {
            curSlt = _p1Slt;
        }
        if (!curSlt && (
            _p2Slt && _p2Slt.enabled
        )) {
            curSlt = _p2Slt;
        }

        if (!curSlt) {
            return;
        }

//			if(isHoverFighter(curSlt, target)){
        if (curSlt.touchHoverItem == target) {
            doSelect(target);
            curSlt.touchHoverItem = null;
        }
        else {
            curSlt.touchHoverItem = target;
            doHover(target);
        }

    }

    private function doHover(target:SelectFighterItem):void {
        if (_p1Slt && _p1Slt.enabled) {

            if (_p1Slt.moreEnabled() && target.isMore) {
                moveToSelectFighterMore(_p1Slt, target);
                SoundCtrl.I.sndSelect();
                return;
            }

            if (checkSelected(_p1Slt, target)) {
                return;
            }
            moveToSelectFighter(_p1Slt, target);
            SoundCtrl.I.sndSelect();
            return;
        }
        if (_p2Slt && _p2Slt.enabled) {

            if (_p2Slt.moreEnabled() && target.isMore) {
                moveToSelectFighterMore(_p2Slt, target);
                SoundCtrl.I.sndSelect();
                return;
            }

            if (checkSelected(_p2Slt, target)) {
                return;
            }
            moveToSelectFighter(_p2Slt, target);
            SoundCtrl.I.sndSelect();
            return;
        }
    }

    private function checkSelected(slt:SelecterItemUI, sf:SelectFighterItem):Boolean {

        if (!sf.selectData && !sf.fighterData) {
            return false;
        }

        if (!sf.selectData && sf.fighterData) {
            return slt.isSelected(sf.fighterData.id);
        }

        if (sf.selectData.moreFighterIDs) {
            for (var i:int; i < sf.selectData.moreFighterIDs.length; i++) {
                if (slt.isSelected(sf.selectData.moreFighterIDs[i])) {
                    return true;
                }
            }
        }
        return slt.isSelected(sf.selectData.fighterID);
    }

    private function doSelect(target:SelectFighterItem):void {
        if (_p1Slt && _p1Slt.enabled) {
            if (checkSelected(_p1Slt, target)) {
                return;
            }
            _p1Slt.select(playerSeltBack);
            SoundCtrl.I.sndConfrim();
            return;
        }
        if (_p2Slt && _p2Slt.enabled) {
            if (checkSelected(_p2Slt, target)) {
                return;
            }
            _p2Slt.select(playerSeltBack);
            SoundCtrl.I.sndConfrim();
            return;
        }
    }

    private function getFighterItem(x:int, y:int):SelectFighterItem {
        if (!_itemObj) {
            return null;
        }
        return _itemObj[x + ',' + y];
    }

    private function initSelecter():void {

        GameInputer.enabled = true;

        if (GameMode.isVsPeople()) {
            initSelecterP1();
            initSelecterP2();
            _twoPlayerSelectFin = false;
        }
        else {
            initSelecterP1();
        }
    }

    private function initSelecterP1():void {
        _p1Slt                  = SelectUIFactory.createSelecter(1);
        _p1Slt.isSelectAssist   = _selectState == SELECT_STATE_ASSIST;
        _p1Slt.selectTimesCount = (
                                          GameMode.isTeamMode() && !_p1Slt.isSelectAssist
                                  ) ? 3 : 1;

        _fighterListUI.addChild(_p1Slt.ui);

//			_ui.addChild(_p1Slt.ui);
        _ui.addChild(_p1Slt.group);
        moveSlt(_p1Slt, 0, 0);
    }

    private function initSelecterP2():void {
        _p2Slt                  = SelectUIFactory.createSelecter(2);
        _p2Slt.isSelectAssist   = _selectState == SELECT_STATE_ASSIST;
        _p2Slt.selectTimesCount = (
                                          GameMode.isTeamMode() && !_p2Slt.isSelectAssist
                                  ) ? 3 : 1;

        _fighterListUI.addChild(_p2Slt.ui);

//			_ui.addChild(_p2Slt.ui);
        _ui.addChild(_p2Slt.group);
        moveSlt(_p2Slt, 9, 0);
    }

    private function moveSlt(slt:SelecterItemUI, x:int, y:int, fix:Boolean = true):Boolean {
        var sf:SelectFighterItem = getFighterItem(x, y);
        var left:Boolean, right:Boolean, up:Boolean, down:Boolean;

        if (!sf || (
                sf && checkSelected(slt, sf)
        )) {
            if (!fix) {
                return true;
            }

            var i:int, j:int;

            if (x > slt.x) {
                right = true;
                for (i = 0; i < _curListConfig.HCount; i++) {
                    j = x + i;
                    if (j > _curListConfig.HCount - 1) {
                        j -= _curListConfig.HCount;
                    }
                    sf = getFighterItem(j, slt.y);
                    if (sf && !checkSelected(slt, sf)) {
                        break;
                    }
                }
            }

            if (x < slt.x) {
                left = true;
                for (i = 0; i < _curListConfig.HCount; i++) {
                    j = x - i;
                    if (j < 0) {
                        j = _curListConfig.HCount + j;
                    }
                    sf = getFighterItem(j, slt.y);
                    if (sf && !checkSelected(slt, sf)) {
                        break;
                    }
                }
            }

            if (y > slt.y) {
                down = true;
                if (y > _curListConfig.VCount - 1) {
                    y = 0;
                }
                for (i = y; i < _curListConfig.VCount; i++) {
                    sf = getHLineFighter(slt.x, i);
//						if(sf && !slt.isSelected(sf.selectData.fighterID)) break;
                    if (sf) {
                        break;
                    }
                }
            }

            if (y < slt.y) {
                up = true;
                if (y < 0) {
                    y = _curListConfig.VCount - 1;
                }
                for (i = y; i >= 0; i--) {
                    sf = getHLineFighter(slt.x, i);
//						if(sf && !slt.isSelected(sf.selectData.fighterID)) break;
                    if (sf) {
                        break;
                    }
                }
            }

        }

        if (!sf) {
            return false;
        }

        slt.x = sf.selectData.x;
        slt.y = sf.selectData.y;

        if (checkSelected(slt, sf)) {
            if (up || down) {
                //Ã¤Â¸â€¹Ã¤Â¸â‚¬Ã¨Â¡Å’Ã¥Â·Â²Ã¨Â¢Â«Ã©â‚¬â€°Ã¤Â¸Â­Ã¯Â¼Å’Ã¥Ââ€˜Ã¥ÂÂ³Ã§Â§Â»Ã¤Â¸â‚¬Ã¤Â¸Âª
                var succ:Boolean = moveSlt(slt, slt.x + 1, slt.y);
                if (!succ) {
                    //Ã¥Â¦â€šÃ¦Å¾Å“Ã¤Â¸Å Ã¤Â¸â‚¬Ã¨Â¡Å’Ã¦Ë†â€“Ã¤Â¸â€¹Ã¤Â¸â‚¬Ã¨Â¡Å’Ã¥Â·Â²Ã§Â»ÂÃ©â‚¬â€°Ã¦Â»Â¡Ã¯Â¼Å’Ã§Â»Â§Ã§Â»Â­Ã¦â€°Â¾Ã¤Â¸Å Ã¤Â¸â‚¬Ã¨Â¡Å’Ã¦Ë†â€“Ã¤Â¸â€¹Ã¤Â¸â‚¬Ã¨Â¡Å’
                    if (up) {
                        moveSlt(slt, slt.x, slt.y - 1);
                    }
                    if (down) {
                        moveSlt(slt, slt.x, slt.y + 1);
                    }
                }
            }
            return true;
        }

        moveToSelectFighter(slt, sf);

        return true;
    }

    private function isHoverFighter(slt:SelecterItemUI, sf:SelectFighterItem):Boolean {
        if (!sf.selectData) {
            return false;
        }
        return (
                       slt.x == sf.selectData.x
               ) && (
                       slt.y == sf.selectData.y
               );
    }

    private function moveToSelectFighter(slt:SelecterItemUI, sf:SelectFighterItem):void {
        if (!sf || !sf.selectData) {
            return;
        }

        slt.randoms = null;

        slt.x = sf.selectData.x;
        slt.y = sf.selectData.y;

        slt.moveTo(sf.ui.x, sf.ui.y);

        slt.currentFighter = sf.fighterData;

        if (slt.group) {
            slt.group.updateFighter(slt.currentFighter);
        }

        checkRandom(slt);

        showMoreFighters(slt, sf);
    }

    private function moveToSelectFighterMore(slt:SelecterItemUI, sf:SelectFighterItem):void {
        slt.randoms = null;

        slt.moreX = sf.position.x;
        slt.moreY = sf.position.y;

        slt.moveTo(sf.ui.x, sf.ui.y);
        slt.currentFighter = sf.fighterData;

        if (slt.group) {
            slt.group.updateFighter(slt.currentFighter);
        }
    }

    /**
     * Ã¤ÂºÂºÃ§â€°Â©Ã¥â€¦Â³Ã¨Ââ€Ã§Å¡â€žÃ¦â€ºÂ´Ã¥Â¤Å¡Ã¤ÂºÂºÃ§â€°Â©
     */
    private function showMoreFighters(slt:SelecterItemUI, sf:SelectFighterItem):void {

        if (slt.showingMoreSelecter == sf) {
            return;
        }

        var fighterItems:ArrayMap;
        var si:SelectFighterItem;
        var i:int;

        fighterItems = _moreFighterMap[slt];
        if (fighterItems) {
            for (i = 0; i < fighterItems.length; i++) {
                si = fighterItems.getItemByIndex(i);
                si.hideMore();
            }
            _moreFighterMap[slt] = null;
        }
        slt.setMoreEnabled(false);

        if (!sf.selectData.moreFighterIDs || sf.selectData.moreFighterIDs.length < 1) {
            return;
        }


        // Ã¦Â£â‚¬Ã¦Å¸Â¥Ã§Â¼â€œÃ¥Â­Ëœ ===========================================================
        fighterItems = _moreFighterCache[sf.fighterData.id];
        if (fighterItems && fighterItems.length > 0) {
            for (i = 0; i < fighterItems.length; i++) {
                si = fighterItems.getItemByIndex(i);
                _fighterListUI.addChild(si.ui);
                si.showMore(i * 0.01);
            }
            _moreFighterMap[slt] = fighterItems;
            slt.setMoreEnabled(true, sf);
            return;
        }

        // Ã¥Ë†â€ºÃ¥Â»ÂºÃ¦â€“Â°Ã§Å¡â€žÃ¥Â¤Â´Ã¥Æ’Â =====================================================
        var fighterIds:Array = sf.selectData.moreFighterIDs;

        fighterItems = new ArrayMap();

        // Ã¥â€˜Â¨Ã¥â€ºÂ´, Ã¤Â¸â‚¬Ã¥Å“Ë†8Ã¤Â¸ÂªÃ¤Â½ÂÃ§Â½Â®
        var posArr:Array = [
            new Point(0, -1), new Point(0, 1), new Point(-1, 0), new Point(1, 0), new Point(-1, -1), new Point(1, -1),
            new Point(-1, 1), new Point(1, 1)
        ];
        var posSN:int    = 0;

        for (i = 0; i < fighterIds.length; i++) {
            var fid:String = fighterIds[i];
            trace(fid);

            var fv:FighterVO = _selectState == SELECT_STATE_ASSIST ? AssisterModel.I.getAssister(fid) :
                               FighterModel.I.getFighter(fid);
            if (!fv) {
                Debugger.log('SelectFighterStage.addFighterItem :: Ã¦Å“ÂªÃ¦â€°Â¾Ã¥Ë†Â°Ã¨Â§â€™Ã¨â€°Â²Ã¦â€¢Â°Ã¦ÂÂ®Ã¯Â¼Å¡' + fid);
                continue;
            }

            var unitWidth:Number  = 60;
            var unitHeight:Number = 60;

            var morePosition:Point = null;
            var addN:int           = 0;
            var fighterPos:Point   = null;
            var loopCount:int      = 0;
            while (morePosition == null) {
                var psn:int = posSN % 8;
                posSN++;
                loopCount++;

                var pos:Point = posArr[psn];
                if (!pos) {
                    Debugger.log('posÃ¦Å“ÂªÃ¥Â®Å¡Ã¤Â¹â€°' + psn + ' / ' + posSN);
                    continue;
                }

                var mmx:Number = sf.ui.x + (
                        pos.x * (
                                unitWidth + 5
                        )
                );
                var mmy:Number = sf.ui.y + (
                        pos.y * (
                                unitHeight + 5
                        )
                );

                if (loopCount <= 8) {
                    if (mmx + _fighterListUI.x < 0 || mmx + _fighterListUI.x > GameConfig.GAME_SIZE.x) {
                        Debugger.log('pos.x Ã¨Â¶Å Ã§â€¢Å’ (' + mmx + ')  ' + psn + ' / ' + posSN);
                        continue;
                    }
                    if (mmy + _fighterListUI.y < 0 || mmy + _fighterListUI.y > GameConfig.GAME_SIZE.y) {
                        Debugger.log('pos.y Ã¨Â¶Å Ã§â€¢Å’ (' + mmy + ')  ' + psn + ' / ' + posSN);
                        continue;
                    }
                }

                fighterPos   = pos.clone();
                morePosition = new Point(mmx, mmy);
            }

            si = new SelectFighterItem(fv, null, true);
            trace(posSN, morePosition, si.fighterData.id);

            if (GameConfig.TOUCH_MODE) {
                si.addEventListener(TouchEvent.TOUCH_TAP, selectFighterTouchHandler);
            }
            else {
                si.addEventListener(MouseEvent.MOUSE_OVER, selectFighterMouseHandler);
                si.addEventListener(MouseEvent.CLICK, selectFighterMouseHandler);
            }

            si.position = fighterPos;

            si.initMoreTween(new Point(sf.ui.x, sf.ui.y), morePosition);
            _fighterListUI.addChild(si.ui);

            addN++;

            si.showMore(addN * 0.01);

            fighterItems.push(si.positionId, si);
            _moreFighterMap[slt]                 = fighterItems;
            _moreFighterCache[sf.fighterData.id] = fighterItems;

        }

        slt.setMoreEnabled(true, sf);
    }

    private function moveMoreSlt(slt:SelecterItemUI, x:int, y:int):Boolean {
        var moreFighters:ArrayMap = _moreFighterMap[slt];

        if (!moreFighters || moreFighters.length < 1) {
            return false;
        }

        if (x == 0 && y == 0 && slt.showingMoreSelecter) {
            slt.moreX = 0;
            slt.moreY = 0;

            slt.moveTo(slt.showingMoreSelecter.ui.x, slt.showingMoreSelecter.ui.y);
            slt.currentFighter = slt.showingMoreSelecter.fighterData;
            if (slt.group) {
                slt.group.updateFighter(slt.currentFighter);
            }
            return true;
        }

        var itemId:String          = SelectFighterItem.getIdByPoint(x, y);
        var item:SelectFighterItem = moreFighters.getItemById(itemId);

        if (!item) {
            return false;
        }

        if (slt.isSelected(item.fighterData.id)) {
            return false;
        }

        slt.randoms = null;

        slt.moreX = item.position.x;
        slt.moreY = item.position.y;

        slt.moveTo(item.ui.x, item.ui.y);
        slt.currentFighter = item.fighterData;

        if (slt.group) {
            slt.group.updateFighter(slt.currentFighter);
        }

        return true;
    }

    /**
     * *******************************************************************************************************************************************************
     */

    private function checkRandom(slt:SelecterItemUI):Boolean {
        if (slt.currentFighter.id.indexOf('random') != -1) {
            switch (_selectState) {
            case SELECT_STATE_FIGHTER:
                slt.randoms = FighterModel.I.getFighters(slt.currentFighter.comicType, function (fv:FighterVO):Boolean {
                    return fv.id.indexOf('random') == -1 && GameLogic.canSelectFighter(fv.id) &&
                           !slt.selectVO.isSelected(fv.id);
                });
                break;
            case SELECT_STATE_ASSIST:
                slt.randoms = AssisterModel.I.getAssisters(
                        slt.currentFighter.comicType, function (fv:FighterVO):Boolean {
                            return fv.id.indexOf('random') == -1 && GameLogic.canSelectAssist(fv.id);
                        });
                break;
            default:
                return false;
            }
            slt.randFrame = 0;
            renderRandom(slt);
            return true;
        }

        return false;
    }

    private function getHLineFighter(startX:int, Y:int):SelectFighterItem {
        var X:int, k:int;
        var sf:SelectFighterItem;
        while (true) {
            X = startX + k;
            if (X >= 0 && X < _curListConfig.HCount) {
                sf = getFighterItem(X, Y);
                if (sf) {
                    return sf;
                }
            }

            if (k == 0) {
                k = 1;
            }
            else if (k > 0) {
                k *= -1;
            }
            else {
                if (k < -_curListConfig.HCount) {
                    return null;
                }
                k *= -1;
                k++;
            }
        }
        return null;
    }

    private function renderRandom(selt:SelecterItemUI):void {
        if (selt.randoms) {
            if (selt.randFrame > 0) {
                selt.randFrame = 0;
                return;
            }
            selt.randFrame++;
            selt.currentFighter = KyoRandom.getRandomInArray(selt.randoms, false);
            if (selt.group) {
                selt.group.updateFighter(selt.currentFighter);
            }
        }
    }

    private function moveSelecter(slt:SelecterItemUI, addX:int, addY:int):void {
        if (slt.moreEnabled()) {
            if (moveMoreSlt(slt, slt.moreX + addX, slt.moreY + addY)) {
                return;
            }
            else {
                slt.setMoreEnabled(false);
            }
        }

        if (moveSlt(slt, slt.x + addX, slt.y + addY)) {
            syncPageToSelecter(slt);
        }
    }

    private function render():void {
        if (_pageChanging) {
            return;
        }

        if (GameInputer.back(1)) {
            if (GameUI.showingDialog()) {
                GameUI.cancelConfrim();
            }
            else {
                GameUI.confrim('BACK TITLE?', 'Ã¨Â¿â€Ã¥â€ºÅ¾Ã¥Ë†Â°Ã¤Â¸Â»Ã¨ÂÅ“Ã¥Ââ€¢Ã¯Â¼Å¸', MainGame.I.goMenu, null, IsMobile());
                GameEvent.dispatchEvent(GameEvent.CONFRIM_BACK_MENU);
            }
        }

        if (GameUI.showingDialog()) {
            return;
        }

        var type:String;

        if (_p1Slt && _p1Slt.enabled) {

            renderRandom(_p1Slt);

            type = _p1Slt.inputType;

            if (GameInputer.up(type, 1)) {
                moveSelecter(_p1Slt, 0, -1);
                SoundCtrl.I.sndSelect();
            }

            if (GameInputer.down(type, 1)) {
                moveSelecter(_p1Slt, 0, 1);
                SoundCtrl.I.sndSelect();
            }

            if (GameInputer.left(type, 1)) {
                moveSelecter(_p1Slt, -1, 0);
                SoundCtrl.I.sndSelect();
            }

            if (GameInputer.right(type, 1)) {
                moveSelecter(_p1Slt, 1, 0);
                SoundCtrl.I.sndSelect();
            }

            if (GameInputer.select(type, 1)) {
                _p1Slt.select(playerSeltBack);
                SoundCtrl.I.sndConfrim();
            }

        }

        if (_p2Slt && _p2Slt.enabled) {

            type = _p2Slt.inputType;

            renderRandom(_p2Slt);

            if (GameInputer.up(type, 1)) {
                moveSelecter(_p2Slt, 0, -1);
                SoundCtrl.I.sndSelect();
            }

            if (GameInputer.down(type, 1)) {
                moveSelecter(_p2Slt, 0, 1);
                SoundCtrl.I.sndSelect();
            }

            if (GameInputer.left(type, 1)) {
                moveSelecter(_p2Slt, -1, 0);
                SoundCtrl.I.sndSelect();
            }

            if (GameInputer.right(type, 1)) {
                moveSelecter(_p2Slt, 1, 0);
                SoundCtrl.I.sndSelect();
            }

            if (GameInputer.select(type, 1)) {
                _p2Slt.select(playerSeltBack);
                SoundCtrl.I.sndConfrim();
            }

        }

        if (_mapSelectUI && _mapSelectUI.enabled) {
            type = _mapSelectUI.inputType;

            if (GameInputer.left(type, 1)) {
                _mapSelectUI.prev();
                SoundCtrl.I.sndSelect();
            }

            if (GameInputer.right(type, 1)) {
                _mapSelectUI.next();
                SoundCtrl.I.sndSelect();
            }

            if (GameInputer.select(type, 1)) {
                _mapSelectUI.select(onMapSelect);
                SoundCtrl.I.sndConfrim();
            }

        }

    }

    private function playerSeltBack(selt:SelecterItemUI):void {
        if (selt.selectFinish()) {
            if (GameMode.isVsPeople()) {
                GameEvent.dispatchEvent(GameEvent.SELECT_FIGHTER_STEP, selt.getCurrentSelectes());

                var otherSlt:SelecterItemUI = selt == _p1Slt ? _p2Slt : _p1Slt;
                if (otherSlt && otherSlt.selectFinish() && !_twoPlayerSelectFin) {
                    _twoPlayerSelectFin = true;
                    if (!AUTO_FINISH) {
                        return;
                    }
                    nextStep();
                }
            }
            else {
                nextStep();
            }
            selt.destory();
//				if(selt == _p1Slt) _p1Slt = null;
//				if(selt == _p2Slt) _p2Slt = null;
        }
        else {
            if (!selt.randoms) {
                var move:int = selt == _p1Slt == 1 ? 1 : -1;
                moveSlt(selt, selt.x + move, selt.y, true);
            }
        }
    }

    private function initMap():void {
        trace('Ã©â‚¬â€°Ã¦â€¹Â©Ã¥Å“Â°Ã¥â€ºÂ¾');

        GameEvent.dispatchEvent(GameEvent.SELECT_MAP);

        clear();

        GameInputer.enabled = false;

        _mapSelectUI = new SelectMapUI();
        _ui.addChild(_mapSelectUI);


        var oldX:Number = _mapSelectUI.x;
        var oldY:Number = _mapSelectUI.y;

        _mapSelectUI.scaleX = 0;
        _mapSelectUI.scaleY = 0;
        _mapSelectUI.x      = GameConfig.GAME_SIZE.x / 2;
        _mapSelectUI.y      = GameConfig.GAME_SIZE.y / 2;
        TweenLite.to(_mapSelectUI, 0.3, {
            x: oldX, y: oldY, scaleX: 1, scaleY: 1, ease: Back.easeOut, onComplete: function ():void {
                if (_mapSelectUI) {
                    _mapSelectUI.addMouseEvents(mapPrevHandler, mapNextHandler, mapConfrimHandler);
                    _mapSelectUI.inputType = GameInputType.P1;
                    _mapSelectUI.enabled   = true;
                }
                GameInputer.enabled = true;
            }
        });

        if (GameConfig.TOUCH_MODE) {
            initBackBtn();
        }
    }

    private function mapPrevHandler():void {
        _mapSelectUI.prev();
    }

    private function mapNextHandler():void {
        _mapSelectUI.next();
    }

    private function mapConfrimHandler():void {
        _mapSelectUI.select(onMapSelect);
    }

    private function onMapSelect():void {
        nextStep();
    }

    private function startAcradeGame():void {
        MessionModel.I.initMession();
        selectFinish();
    }

    private function startMosouGame():void {
//			MosouMissionModel.I.initMissions();
        selectFinish();
    }

    private function selectFinish():void {
        GameEvent.dispatchEvent(GameEvent.SELECT_FIGHTER_FINISH);
        if (!AUTO_FINISH) {
            return;
        }
        goLoadGame();
    }

    private function backMenuHandler(e:Event):void {
        GameUI.confrim('BACK TITLE?', 'Ã¨Â¿â€Ã¥â€ºÅ¾Ã¥Ë†Â°Ã¤Â¸Â»Ã¨ÂÅ“Ã¥Ââ€¢Ã¯Â¼Å¸', MainGame.I.goMenu, null, IsMobile());
        GameEvent.dispatchEvent(GameEvent.CONFRIM_BACK_MENU);
    }

    private function pageUpHandler(e:Event):void {
        setSelectPage(_pageIndex - 1, true);
    }

    private function pageDownHandler(e:Event):void {
        setSelectPage(_pageIndex + 1, true);
    }

    private function setSelectPage(page:int, moveSelecters:Boolean = false):void {
        if (_pageCount <= 1) {
            return;
        }

        if (page < 0) {
            page = 0;
        }
        if (page > _pageCount - 1) {
            page = _pageCount - 1;
        }
        if (page == _pageIndex && _fighterListUI.y == -SELECT_PAGE_STEP * page) {
            return;
        }

        _pageIndex          = page;
        _pageChanging       = true;
        GameInputer.enabled = false;

        if (moveSelecters) {
            moveSelecterToPage(_p1Slt);
            moveSelecterToPage(_p2Slt);
        }

        var targetPage:int = _pageIndex;
        TweenLite.killTweensOf(_fighterListUI);
        TweenLite.to(_fighterListUI, .16, {
            y: -SELECT_PAGE_STEP * targetPage,
            onComplete: function ():void {
                _pageChanging       = false;
                GameInputer.enabled = true;
            }
        });
    }

    private function moveSelecterToPage(slt:SelecterItemUI):void {
        if (!slt || !slt.enabled || !_curListConfig) {
            return;
        }

        var minRow:int = _pageIndex * SELECT_PAGE_ROWS;
        var maxRow:int = Math.min(_curListConfig.VCount - 1, minRow + SELECT_PAGE_ROWS - 1);
        if (slt.y >= minRow && slt.y <= maxRow) {
            var snapItem:SelectFighterItem = getFighterItem(slt.x, slt.y);
            if (snapItem) {
                slt.moveTo(snapItem.ui.x, snapItem.ui.y);
            }
            return;
        }

        if (!moveSlt(slt, slt.x, minRow, true)) {
            for (var row:int = minRow; row <= maxRow; row++) {
                if (moveSlt(slt, 0, row, true)) {
                    return;
                }
            }
        }
    }

    private function syncPageToSelecter(slt:SelecterItemUI):void {
        if (!slt || _pageCount <= 1 || _pageChanging) {
            return;
        }

        var page:int = int(slt.y / SELECT_PAGE_ROWS);
        if (page != _pageIndex) {
            setSelectPage(page);
        }
    }
}
}

