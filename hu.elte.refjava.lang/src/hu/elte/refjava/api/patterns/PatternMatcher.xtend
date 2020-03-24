package hu.elte.refjava.api.patterns

import hu.elte.refjava.lang.refJava.PBlockExpression
import hu.elte.refjava.lang.refJava.PConstructorCall
import hu.elte.refjava.lang.refJava.PExpression
import hu.elte.refjava.lang.refJava.PMemberFeatureCall
import hu.elte.refjava.lang.refJava.PMetaVariable
import hu.elte.refjava.lang.refJava.PMethodDeclaration
import hu.elte.refjava.lang.refJava.PTargetExpression
import hu.elte.refjava.lang.refJava.Pattern
import java.lang.reflect.Type
import java.util.ArrayList
import java.util.List
import java.util.Map
import java.util.Queue
import org.eclipse.jdt.core.dom.ASTNode
import org.eclipse.jdt.core.dom.Block
import org.eclipse.jdt.core.dom.ClassInstanceCreation
import org.eclipse.jdt.core.dom.ExpressionStatement
import org.eclipse.jdt.core.dom.MethodDeclaration
import org.eclipse.jdt.core.dom.MethodInvocation
import org.eclipse.jdt.core.dom.Modifier
import org.eclipse.xtext.EcoreUtil2

class PatternMatcher {
	
	ArrayList<ASTNode> modifiedTarget
	val Pattern pattern
	Map<String, List<? extends ASTNode>> bindings = newHashMap
	Map<String, String> nameBindings
	Map<String, Type> typeBindings
	Map<String, List<Pair<Type, String>>> parameterBindings
	Queue<String> typeReferenceQueue
	
	new(Pattern pattern) {
		this.pattern = pattern
	}

	def getBindings() {
		bindings
	}
	
	def getModifiedTarget() {
		modifiedTarget
	}
	
	def match(Pattern targetPattern, List<? extends ASTNode> target) {
		bindings.clear
		return doMatchChildren(targetPattern.patterns, target)
	}

	//this function gets called during the matching
	def match(List<? extends ASTNode> target, Map<String, String> nameBindings, Map<String, Type> typeBindings, Map<String, List<Pair<Type, String>>> parameterBindings, String typeRefString) {
		this.nameBindings = nameBindings
		this.typeBindings = typeBindings
		this.parameterBindings = parameterBindings
		val tmp = typeRefString.split("\\|")
		this.typeReferenceQueue = newLinkedList
		this.typeReferenceQueue.addAll(tmp)
		
		
		bindings.clear
		modifiedTarget = newArrayList
		modifiedTarget.addAll(target)
		
		val patterns = pattern.patterns
		val isTargetExists = EcoreUtil2.getAllContentsOfType(pattern, PTargetExpression).size > 0
		if (!isTargetExists) {
			doMatchChildren(patterns, target)	
		} else {
			doMatchChildrenWithTarget(patterns, target)			
		}
	}

	///////////////////////
	// doMatch overloads //
	///////////////////////
	def private dispatch doMatch(PMetaVariable metaVar, ASTNode anyNode) {
		bindings.put(metaVar.name, #[anyNode])
		true
	}
	
	def private dispatch doMatch(PMetaVariable multiMetavar, List<ASTNode> nodes) {
		bindings.put(multiMetavar.name, nodes)
		true
	}
	
	def private dispatch boolean doMatch(PBlockExpression blockPattern, Block block) {
		doMatchChildren(blockPattern.expressions, block.statements)
	}
	
	//constructor call matching
	def private dispatch boolean doMatch(PConstructorCall constCall, ClassInstanceCreation classInstance) {
		
		//matching constructor call name
		var boolean nameCheck
		if (constCall.metaName !== null) {
			//TODO
			nameCheck = true
		} else {
			nameCheck = constCall.name == classInstance.type.toString
		}
		
		//matching constructor call's methods
		var boolean anonClassCheck
		if (classInstance.anonymousClassDeclaration !== null && constCall.elements !== null) {
			if (constCall.elements.size != classInstance.anonymousClassDeclaration.bodyDeclarations.size) {
				return false
			} else {
				/*
				val pIt = constCall.elements.iterator
				val nIt = classInstance.anonymousClassDeclaration.bodyDeclarations.iterator
				while(pIt.hasNext) {
					if (!doMatch(pIt.next, nIt.next)) {
						return false
					}
				}
				anonClassCheck = true
				*/
				anonClassCheck = doMatchChildren(constCall.elements, classInstance.anonymousClassDeclaration.bodyDeclarations)
			}	
		} else {
			//TODO
			anonClassCheck = true
		}
		
		return nameCheck && anonClassCheck
	}
	
	//method matching
	def private dispatch boolean doMatch(PMethodDeclaration pMethodDecl, MethodDeclaration methodDecl) {
		
		//matching method name
		var boolean nameCheck
		if(pMethodDecl.prefix.metaName !== null) {
			//TODO
			nameCheck = true
		} else {
			nameCheck = pMethodDecl.prefix.name == methodDecl.name.identifier
		}
		
		//matching method visibility
		var boolean visibilityCheck 
		if(pMethodDecl.prefix.visibility !== null) {
			switch pMethodDecl.prefix.visibility {
				case PUBLIC: visibilityCheck = Modifier.isPublic(methodDecl.getModifiers())
				case PRIVATE: visibilityCheck = Modifier.isPrivate(methodDecl.getModifiers())
				case PROTECTED: visibilityCheck = Modifier.isProtected(methodDecl.getModifiers())
				default: {}
			}
		}
		
		//matching method return value
		var boolean returnCheck
		if(pMethodDecl.prefix.metaType !== null) {
			//TODO
			returnCheck = true
		} else {
			returnCheck = methodDecl.returnType2.toString == typeReferenceQueue.remove 
		}
		
		//matching method body
		val boolean bodyCheck = doMatch(pMethodDecl.body, methodDecl.body)
		
		return nameCheck && visibilityCheck && returnCheck && bodyCheck
	}
	
	//method invocation matching
	def private dispatch boolean doMatch(PMemberFeatureCall featureCall, ExpressionStatement expStatement) {
		if (expStatement.expression instanceof MethodInvocation) {
			val methodInv = expStatement.expression as MethodInvocation
			
			//matching method invocation name
			var boolean nameCheck
			if (featureCall.feature !== null) {
				nameCheck = featureCall.feature == methodInv.name.identifier
			} else {
				//TODO
				nameCheck = true
			}
			
			//matching method invocation parameters
			var boolean parameterCheck
			if(featureCall.memberCallArguments !== null) {
				//TODO
				parameterCheck = true
			}
						
			//matching method invocation expression
			val boolean expressionCheck = doMatch(featureCall.memberCallTarget, methodInv.expression)

			return nameCheck && parameterCheck && expressionCheck
		} else {
			return false
		}
	}

	def private dispatch doMatch(PExpression anyOtherPattern, ASTNode anyOtherNode) {
		false
	}
	
	///////////////////////
	// children matching //
	///////////////////////
	def private doMatchChildren(List<PExpression> patterns, List<? extends ASTNode> nodes) {
		if (!patterns.exists[it instanceof PMetaVariable && (it as PMetaVariable).multi] && nodes.size != patterns.size) {
			return false
		}
		
		val nIt = nodes.iterator
		for (var int i = 0; i < patterns.size; i++) {
			if( (patterns.get(i) instanceof PMetaVariable && !(patterns.get(i) as PMetaVariable).multi) || !(patterns.get(i) instanceof PMetaVariable) ) {
				if (!doMatch(patterns.get(i), nIt.next)) {
					return false
				}
			} else {
				val preMultiMetavar = patterns.take(i).size
				val postMultiMetavar = patterns.drop(i + 1).size
				var List<ASTNode> matchingNodes = newArrayList
				var int j = 0
				
				while (j != nodes.size - (preMultiMetavar + postMultiMetavar) ) {
					matchingNodes.add(nIt.next)
					j++
				}
	
				if(!doMatch(patterns.get(i), matchingNodes)) {
					return false
				}
			}
		}
		true
	}
	
	
	def private doMatchChildrenWithTarget(List<PExpression> patterns, List<? extends ASTNode> selectedNodes) {
		var List<PExpression> preTargetExpression = patterns.clone.takeWhile[ !(it instanceof PTargetExpression) ].toList.reverse
		var List<PExpression> postTargetExpression = patterns.clone.reverse.takeWhile[ !(it instanceof PTargetExpression) ].toList.reverse
		
		val List<?super ASTNode> targetEnvironment = newArrayList
		targetEnvironment.addAll( (selectedNodes.head.parent as Block).statements )
			
		var List<ASTNode> preSelectedNodes = (targetEnvironment as List<?extends ASTNode>).clone.takeWhile[ it != selectedNodes.head ].toList.reverse
		var List<ASTNode> postSelectedNodes = (targetEnvironment as List<?extends ASTNode>).clone.reverse.takeWhile[ it != selectedNodes.last ].toList.reverse
		
		var Boolean pre
		var Boolean post
		
		if (!preTargetExpression.exists[ it instanceof PMetaVariable && (it as PMetaVariable).isMulti] ) {	
			val preSelectedNodesToMatch = preSelectedNodes.clone.take(preTargetExpression.size).toList
			pre = doMatchChildren(preTargetExpression, preSelectedNodesToMatch)
			modifiedTarget.addAll(0, preSelectedNodesToMatch)
		} else {
			pre = doMatchChildren(preTargetExpression, preSelectedNodes)
			modifiedTarget.addAll(0, preSelectedNodes)
		}
		
		if (!postTargetExpression.exists[ it instanceof PMetaVariable && (it as PMetaVariable).isMulti] ) {	
			val postSelectedNodesToMatch = postSelectedNodes.clone.take(postTargetExpression.size).toList	
			post = doMatchChildren(postTargetExpression, postSelectedNodesToMatch)
			modifiedTarget.addAll(postSelectedNodesToMatch)
		} else {
			post = doMatchChildren(postTargetExpression, postSelectedNodes)
			modifiedTarget.addAll(postSelectedNodes)
		}
		bindings.put("target", selectedNodes)
		return pre && post	
	}
}
