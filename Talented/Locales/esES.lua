local L =  LibStub:GetLibrary("AceLocale-3.0"):NewLocale("Talented", "esES", false)
if not L then return end

L["%d/%d"] = "%d/%d"
L["%s (%d)"] = "%s (%d)"
L["\"%s\" does not appear to be a valid URL!"] = "¡ \"%s\" no parece ser una URL válida !"
L["Actions"] = "Acciones"
L["Add bottom offset"] = "Añadir espaciado inferior"
L["Add some space below the talents to show the bottom information."] = "Añade algo de espacio bajo los talentos para mostrar la información inferior."
L["Always allow templates and the current build to be modified, instead of having to Unlock them first."] = "Permite que las plantillas y la build actual sean modificados directamente, en vez de tener que desbloquearlos primero."
L["Always call the underlying API when a user input is made, even when no talent should be learned from it."] = "Siempre llama al API subllacente con las acciones del usuario, incluso cuando no conlleve el aprendizaje de un talento."
L["Always edit"] = "Editar siempre"
L["Always show the active spec after a change"] = "Siempre muestra la build activa tras un cambio"
L["Always try to learn talent"] = "Siempre intenta aprender talento"
L["Apply template"] = "Aplicar plantilla"
L["Are you sure that you want to learn \"%s (%d/%d)\" ?"] = "¿ Seguro que quieres aprender \"%s (%d/%d)\" ?"
L["Ask for user confirmation before learning any talent."] = "Pide confirmación al usuario antes de aprender algún talento."
L["Can not apply, unknown template \"%s\""] = "No es posible aplicar, plantilla desconocida: \"%s\""
L["Clear target"] = "Limpiar objetivo"
L["Confirm Learning"] = "Confirmar aprendizaje"
L["Copy of %s"] = "Copia de %s"
L["Copy template"] = "Copiar plantilla"
L["Delete template"] = "Borrar plantilla"
L["Directly outputs the URL in Chat instead of using a Dialog."] = "Muestra los enlaces directamente en el chat, en vez de usar una ventana."
L["Display options"] = "Opciones de visualización"
L["Distance between icons."] = "Distancia entre iconos."
L["Do you want to add the template \"%s\" that %s sent you ?"] = "¿ Quieres añadir la plantilla \"%s\" que %s te ha enviado ?"
L["Edit talents"] = "Editar talentos"
L["Edit template"] = "Editar plantilla"
L["Effective tooltip information not available"] = "No hay disponible tooltip con información útil"
L["Empty"] = "Vacío"
L["Enter the complete URL of a template from Blizzard talent calculator or wowhead."] = "Introduce la URL completa de una plantilla del calculador de talentos de Blizzard o WoWHead."
L["Enter the name of the character you want to send the template to."] = "Introduce el nombre del personaje al que quieres enviar la plantilla."
L["Error while applying talents! Not enough talent points!"] = "¡ Error al aplicar talentos ! ¡ No hay suficientes puntos de talento !"
L["Error while applying talents! some of the request talents were not set!"] = "¡ Error al aplicar talentos ! ¡ Alguno de los talentos solicitados no se han establecido !"
L["Error! Talented window has been closed during template application. Please reapply later."] = "¡ Error ! La ventana de talentos se ha cerrado durante el establecimiento de una plantilla. Por favor, aplícala otra vez."
L["Export template"] = "Exportar plantilla"
L["Frame scale"] = "Escala de la ventana"
L["General Options for Talented."] = "Opciones generales de Talented."
L["General options"] = "Opciones generales"
L["Glyph frame options"] = "Opciones de la ventana de glifos"
L["Glyph frame policy on spec swap"] = "Política para la ventana de glifos al cambiar de build"
L["Hook Inspect UI"] = "Enlazar el interfaz de inspección"
L["Hook the Talent Inspection UI."] = "Enlaza el interfaz de inspección de talentos."
L["Icon offset"] = "Separación de iconos"
L["Import template ..."] = "Importar plantilla..."
L["Imported"] = "Importado"
L["Inspected Characters"] = "Personajes inspeccionados"
L["Inspection of %s"] = "Inspección de %s"
L["Keep the shown spec"] = "Mantener la build mostrada"
L["Layout options"] = "Opciones de aspecto"
L["Level %d"] = "Nivel %d"
L["Level restriction"] = "Restricción de nivel"
L["Lock frame"] = "Bloquear ventana"
L["New Template"] = "Nueva plantilla"
L["Nothing to do"] = "Nada que hacer"
L["Options ..."] = "Opciones..."
L["Options"] = "Opciones"
L["Output URL in Chat"] = "Muestra enlaces en el chat"
L["Overall scale of the Talented frame."] = "Escala total de la ventana de Talented."
L["Please wait while I set your talents..."] = "Por favor, espera mientras establezco tus talentos..."
L["Remove all talent points from this tree."] = "Elimina todos los puntos de talentos de este árbol."
L["Restrict templates to a maximum of %d points."] = "Restringe las plantillas a un máximo de %d puntos."
L["Select %s"] = "Selecciona %s"
L["Select the way the glyph frame handle spec swaps."] = "Seleciona el modo en que la ventana de glifos gestiona el cambio de builds."
L["Send to ..."] = "Enviar a ..."
L["Set as target"] = "Establece como objetivo"
L["Show the required level for the template, instead of the number of points."] = "Muestra el nivel requerido por la plantilla, en vez del número de puntos."
L["Sorry, I can't apply this template because it doesn't match your class!"] = "¡ Lo siento, no puedo aplicar esta plantilla porque no coincide con tu clase !"
L["Sorry, I can't apply this template because it doesn't match your pet's class!"] = "¡ Lo siento, no puedo aplicar esta plantilla porque no coincide con la clase de tu mascota !"
L["Sorry, I can't apply this template because you don't have enough talent points available (need %d)!"] = "¡ Lo siento, no puedo aplicar esta plantilla porque no tienes suficientes puntos de talento disponibles (hacen falta %s) !"
L["Swap the shown spec"] = "Cambiar la build mostrada"
L["Switch to this Spec"] = "Cambiar a esta build"
L["Talent application has been cancelled. %d talent points remaining."] = "El establecimiento de talemtos ha sido cancelado. Quedan %d puntos de talento"
L["Talent cap"] = "Límite de talentos"
L["Talented - Talent Editor"] = "Talented - Editor de talentos"
L["Talented has detected an incompatible change in the talent information that requires an update to Talented. Talented will now Disable itself and reload the user interface so that you can use the default interface."] = "Talented ha detectado un cambio incompatible en la información de talentos que requiere una actualización de Talented. Talented se desactivará y cargará de nuevo la interfaz de usuario para que puedas usar el interfaz por defecto."
L["Target: %s"] = "Objetivo: %s"
L["Template applied successfully, %d talent points remaining."] = "Plantilla aplicada exitosamente. Quedan %d puntos de talento"
L["Templates"] = "Plantillas"
L["The following templates are no longer valid and have been removed:"] = "Las siguientes plantillas ya no son válidas y han sido eliminadas:"
L["The given template is not a valid one!"] = "¡ La plantilla especificada no es válida !"
L["Toggle editing of talents."] = "Activa/desactiva la edición de talentos."
L["Toggle edition of the template."] = "Activa/desactiva la edición de la plantilla."
L["View glyphs of alternate Spec"] = "Ver glifos de la build alternaitva"
L["View Pet Spec"] = "Mostrar la build de la mascota"
L["View the Current spec in the Talented frame."] = "Muestra la build actual en la ventana de Talented."
L["WARNING: Talented has detected that its talent data is outdated. Talented will work fine for your class for this session but may have issue with other classes. You should update Talented if you can."] = "CUIDADO: Talented ha detectado que sus datos de talentos están obsoletos. Talented funcionará bien para tu clase durante esta sesión, pero puedes tener problemas con otras clases. Deberías actualizar Talented si puedes."
L["You can edit the name of the template here. You must press the Enter key to save your changes."] = "Puedes editar el nombre de las plantillas aquí. Debes pulsar la tecla Enter para grabar los cambios."
L["You have %d talent |4point:points; left"] = "Tienes %d |4punto:puntos; de talento restantes"