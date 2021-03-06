package hu.elte.refjava.lang.jvmmodel

import com.google.inject.Inject
import hu.elte.refjava.api.BlockRefactoring
import hu.elte.refjava.api.ClassRefactoring
import hu.elte.refjava.api.LambdaRefactoring
import hu.elte.refjava.api.LocalRefactoring
import hu.elte.refjava.api.patterns.Utils
import hu.elte.refjava.lang.refJava.MetaVariableType
import hu.elte.refjava.lang.refJava.PMetaVariable
import hu.elte.refjava.lang.refJava.Pattern
import hu.elte.refjava.lang.refJava.SchemeInstanceRule
import hu.elte.refjava.lang.refJava.SchemeType
import java.util.List
import org.eclipse.jdt.core.dom.Type
import org.eclipse.xtext.common.types.JvmVisibility
import org.eclipse.xtext.naming.IQualifiedNameProvider
import org.eclipse.xtext.serializer.ISerializer
import org.eclipse.xtext.xbase.jvmmodel.AbstractModelInferrer
import org.eclipse.xtext.xbase.jvmmodel.IJvmDeclaredTypeAcceptor
import org.eclipse.xtext.xbase.jvmmodel.JvmTypesBuilder

class RefJavaJvmModelInferrer extends AbstractModelInferrer {

	@Inject extension IQualifiedNameProvider
	@Inject extension ISerializer
	@Inject extension JvmTypesBuilder
	
	def dispatch infer(SchemeInstanceRule rule, IJvmDeclaredTypeAcceptor acceptor, boolean isPreIndexingPhase) {
		acceptor.accept(rule.toClass(rule.fullyQualifiedName)) [
			superTypes += rule.type.toSuperType.typeRef
			
			//type parsing doesn't work..
			val typeRefGetter = [ Pattern pattern |
				if (pattern !== null) { 
					Utils.getTypeReferenceString(pattern)
				} else {
					""
				}
			]
			
			val matchingTypeReferenceString = typeRefGetter.apply(rule.matchingPattern)
			val replacementTypeReferenceString = typeRefGetter.apply(rule.replacementPattern)
			val targetTypeReferenceString = typeRefGetter.apply(rule.targetPattern)
			val definitionTypeReferenceString = typeRefGetter.apply(rule.definitionPattern)
			
			members += rule.toConstructor [
				body = '''super("«rule.matchingPattern.serialize.trim»", "«rule.replacementPattern.serialize.trim»");'''
			]
			
			val endl = System.getProperty("line.separator");
			var String callings = ""
			if(rule.assignments !== null) {
 				for (assignment : rule.assignments.assignment) {
 					val metaVar = assignment.metaVariable as PMetaVariable
 					val metaVarName = (assignment.metaVariable as PMetaVariable).name
					
					if (metaVar.type == MetaVariableType.NAME) {
						members += rule.toMethod("valueof_name_" + metaVarName, typeof(String).typeRef) [
							visibility = JvmVisibility.PRIVATE
							body = assignment.value
						]
						callings = callings + "set_name_" + metaVarName + "();" + endl
						members += rule.toMethod("set_name_" + metaVarName, typeof(void).typeRef) [
							visibility = JvmVisibility.PRIVATE
							body = '''nameBindings.put("«metaVarName»", valueof_name_«metaVarName»());'''
						]
					} else if (metaVar.type == MetaVariableType.TYPE) {
						members += rule.toMethod("valueof_type_" + metaVarName, typeof(Type).typeRef) [
							visibility = JvmVisibility.PRIVATE
							body = assignment.value
						]
						callings = callings + "set_type_" + metaVarName + "();" + endl
						members += rule.toMethod("set_type_" + metaVarName, typeof(void).typeRef) [
							visibility = JvmVisibility.PRIVATE
							body = '''typeBindings.put("«metaVarName»", valueof_type_«metaVarName»());'''
						]
					} else if (metaVar.type == MetaVariableType.PARAMETER) {
						members += rule.toMethod("valueof_parameter_" + metaVarName, typeof(List).typeRef) [
							visibility = JvmVisibility.PRIVATE
							body = assignment.value
						]
						callings = callings + "set_parameter_" + metaVarName + "();" + endl
						members += rule.toMethod("set_parameter_" + metaVarName, typeof(void).typeRef) [
							visibility = JvmVisibility.PRIVATE
							body = '''parameterBindings.put("«metaVarName»", valueof_parameter_«metaVarName»());'''
						]
					} else if (metaVar.type == MetaVariableType.VISIBILITY) {
						members += rule.toMethod("valueof_visibility_" + metaVarName, typeof(List).typeRef) [
							visibility = JvmVisibility.PRIVATE
							body = assignment.value
						]
						callings = callings + "set_visibility_" + metaVarName + "();" + endl
						members += rule.toMethod("set_visibility_" + metaVarName, typeof(void).typeRef) [
							visibility = JvmVisibility.PRIVATE
							body = '''visibilityBindings.put("«metaVarName»", valueof_visibility_«metaVarName»());'''
						]
					} else if(metaVar.type == MetaVariableType.ARGUMENT) {
						members += rule.toMethod("valueof_argument_" + metaVarName, typeof(List).typeRef) [
							visibility = JvmVisibility.PRIVATE
							body = assignment.value
						]
						callings = callings + "set_argument_" + metaVarName + "();" + endl
						members += rule.toMethod("set_argument_" + metaVarName, typeof(void).typeRef) [
							visibility = JvmVisibility.PRIVATE
							body = '''argumentBindings.put("«metaVarName»", valueof_argument_«metaVarName»());'''
						]
					}
				}
			}
			
			if(rule.definitionPattern !== null && (rule.type == SchemeType.LAMBDA || rule.type == SchemeType.CLASS) ) {
				callings = callings + '''super.definitionString = "«rule.definitionPattern.serialize.trim»";'''+ endl
			}
			
			val finalCallings = callings + endl
			if (finalCallings.length > 2 || matchingTypeReferenceString.length > 0 || replacementTypeReferenceString.length > 0 || targetTypeReferenceString.length > 0 || definitionTypeReferenceString.length > 0) {
				members += rule.toMethod("setMetaVariables", typeof(void).typeRef) [
					//annotations += annotationRef(Override)
					visibility = JvmVisibility.PROTECTED
					body = '''«finalCallings»super.matchingTypeReferenceString = "«matchingTypeReferenceString»";
super.replacementTypeReferenceString = "«replacementTypeReferenceString»";
super.targetTypeReferenceString = "«targetTypeReferenceString»";
super.definitionTypeReferenceString = "«definitionTypeReferenceString»";'''
				]
			}
			
			if (rule.precondition !== null) {
				members += rule.toMethod("instanceCheck", Boolean.TYPE.typeRef) [
					visibility = JvmVisibility.PRIVATE
					body = rule.precondition
				]

				members += rule.toMethod("check", Boolean.TYPE.typeRef) [
					annotations += annotationRef(Override)
					visibility = JvmVisibility.PROTECTED
					body = '''return super.check() && instanceCheck();'''
				]
			}
			
			if (rule.targetPattern !== null) {
				members += rule.toMethod("safeTargetCheck", Boolean.TYPE.typeRef) [
					annotations += annotationRef(Override)
					visibility = JvmVisibility.PROTECTED
					body = '''return super.targetCheck("«rule.targetPattern.serialize.trim»");'''
				]
			}
		]
	}

	def private toSuperType(SchemeType it) {
		switch it {
			case LOCAL : LocalRefactoring
			case BLOCK : BlockRefactoring
			case LAMBDA : LambdaRefactoring
			case CLASS : ClassRefactoring
		}
	}

}
