local L =  LibStub:GetLibrary("AceLocale-3.0"):NewLocale("Talented", "zhCN")
if not L then return end

L[" (alt)"] = "（alt"
L["%d/%d"] = "%d/%d"
L["%s (%d)"] = "%s (%d)"
L["\"%s\" does not appear to be a valid URL!"] = "\"%s\"看起来不是一个有效的链接！"
L["Actions"] = "操作"
L["Add bottom offset"] = "添加底部偏移"
L["Add some space below the talents to show the bottom information."] = "在天赋下面添加间距以显示底部信息。"
L["Always allow templates and the current build to be modified, instead of having to Unlock them first."] = "始终允许编辑模板和当前天赋方案，而不需要预先解锁。"
L["Always call the underlying API when a user input is made, even when no talent should be learned from it."] = "始终在玩家进行输入时调用 API，即使没有天赋能够学习。"
L["Always edit"] = "始终编辑"
L["Always show the active spec after a change"] = "总是显示在更改后显示启用的配置方案"
L["Always try to learn talent"] = "始终学习新天赋"
L["Apply template"] = "应用模板"
L["Are you sure that you want to learn \"%s (%d/%d)\" ?"] = "是否确认学习\"%s (%d/%d)\"？"
L["Ask for user confirmation before learning any talent."] = "学习任何天赋前都询问是否确认。"
L["Can not apply, unknown template \"%s\""] = "不能接受，未知模板\"%s\""
L["Clear target"] = "清除目标"
L["Confirm Learning"] = "确认学习"
L["Copy of %s"] = "%s的拷贝"
L["Copy template"] = "复制模板"
L["Delete template"] = "删除模板"
L["Directly outputs the URL in Chat instead of using a Dialog."] = "直接输出链接到聊天框。"
L["Display options"] = "显示选项"
L["Distance between icons."] = "图标间距。"
L["Do you want to add the template \"%s\" that %s sent you ?"] = "是否要添加由\"%s\"发送给你的天赋模板？"
L["Edit talents"] = "编辑天赋"
L["Edit template"] = "编辑模板"
L["Effective tooltip information not available"] = "无有效鼠标提示信息"
L["Empty"] = "空"
L["Enter the complete URL of a template from Blizzard talent calculator or wowhead."] = "请粘帖从暴雪官方或 Wowhead 的天赋模拟器获得的天赋配置链接。"
L["Enter the name of the character you want to send the template to."] = "输入你想要发送到的玩家的名字。"
L["Error while applying talents! Not enough talent points!"] = "应用天赋错误！没有足够的天赋点数！"
L["Error while applying talents! some of the request talents were not set!"] = "应用天赋错误！必备天赋点数没有设置！"
L["Error! Talented window has been closed during template application. Please reapply later."] = "天赋面板在应用过程中被关闭！请稍候重新应用。"
L["Export template"] = "导出模板"
L["Frame scale"] = "框体缩放"
L["General Options for Talented."] = "Talented 综合选项。"
L["General options"] = "一般选项"
L["Glyph frame options"] = "雕文框体选项"
L["Glyph frame policy on spec swap"] = "雕文框体配置方案互换"
L["Hook Inspect UI"] = "替代默认观察窗口"
L["Hook the Talent Inspection UI."] = "使用 Talented 天赋面板替代默认观察窗口。"
L["Icon offset"] = "图标偏移"
L["Import template ..."] = "导入模板…"
L["Imported"] = "已导入"
L["Inspected Characters"] = "观察过的玩家"
L["Inspection of %s"] = "观察%s"
L["Keep the shown spec"] = "保持此显示配置方案"
L["Layout options"] = "样式选项"
L["Level %d"] = "等级%d"
L["Level restriction"] = "等级限制"
L["Lock frame"] = "锁定框体"
L["New Template"] = "新建模板"
L["Nothing to do"] = "什么都不做"
L["Options ..."] = "选项…"
L["Options"] = "选项"
L["Output URL in Chat"] = "输出链接到聊天框"
L["Overall scale of the Talented frame."] = "Talented 总体框体缩放。"
L["Please wait while I set your talents..."] = "正在应用天赋，请等待…"
L["Remove all talent points from this tree."] = "从该天赋系中移除所有点数。"
L["Restrict templates to a maximum of %d points."] = "将模板限制为%d点上限。"
L["Select %s"] = "选择%s"
L["Select the way the glyph frame handle spec swaps."] = "选择雕文框体配置方案互换方式。"
L["Send to ..."] = "发送到…"
L["Set as target"] = "选中为目标"
L["Show the required level for the template, instead of the number of points."] = "显示模板的当前方案所需等级而不是所需天赋点数。"
L["Sorry, I can't apply this template because it doesn't match your class!"] = "抱歉，无法应用该模板，这与你的职业不符！"
L["Sorry, I can't apply this template because it doesn't match your pet's class!"] = "抱歉，无法应用该模板，这与你宠物类型不符！"
L["Sorry, I can't apply this template because you don't have enough talent points available (need %d)!"] = "抱歉，无法应用该模板，你没有足够的天赋点数（还需要%d点）！"
L["Swap the shown spec"] = "互换此显示配置方案"
L["Switch to this Spec"] = "切换到此配置方案"
L["Talent application has been cancelled. %d talent points remaining."] = "应用天赋操作取消，剩余%d天赋点数。"
L["Talent cap"] = "天赋上限"
L["Talented - Talent Editor"] = "Talented - 天赋编辑器"
L["Talented has detected an incompatible change in the talent information that requires an update to Talented. Talented will now Disable itself and reload the user interface so that you can use the default interface."] = "Talented 已发现了不兼容的天赋资料变化并需要更新，Talented 现在将停用并重新加载用户界面，让您可以使用默认界面。"
L["Target: %s"] = "目标：%s"
L["Template applied successfully, %d talent points remaining."] = "成功应用模板，剩余%d天赋点数。"
L["Templates"] = "模板"
L["The following templates are no longer valid and have been removed:"] = "以下模板已失效并已被删除："
L["The given template is not a valid one!"] = "该天赋模板无效！"
L["Toggle editing of talents."] = "编辑天赋方案。"
L["Toggle edition of the template."] = "编辑天赋模板。"
L["URL:"] = "链接："
L["View glyphs of alternate Spec"] = "查看替换雕文配置方案"
L["View Pet Spec"] = "查看宠物配置方案"
L["View the Current spec in the Talented frame."] = "在天赋面板上查看当前配置方案。"
L["WARNING: Talented has detected that its talent data is outdated. Talented will work fine for your class for this session but may have issue with other classes. You should update Talented if you can."] = "警告：Talented 发现其天赋数据已经过期。Talented 可能在您当前的职业正常运作，但可能与其他职业发生问题。请尽快更新 Talented。"
L["You can edit the name of the template here. You must press the Enter key to save your changes."] = "在这里输入模板的名称，按回车键确认改动。"
L["You have %d talent |4point:points; left"] = "您还有%d点天赋点数剩余"