/*
Copyright 2024.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

package controller

import (
	"context"
	"log/slog"
	"os"

	corev1 "k8s.io/api/core/v1"
	"k8s.io/apimachinery/pkg/runtime"
	ctrl "sigs.k8s.io/controller-runtime"
	"sigs.k8s.io/controller-runtime/pkg/client"
)

// KubernetesServicePatcherReconciler reconciles a KubernetesServicePatcher object
type KubernetesServicePatcherReconciler struct {
	client.Client
	Log    *slog.Logger
	Scheme *runtime.Scheme
}

//+kubebuilder:rbac:groups="",resources=services,verbs=get;list;watch;update

// Reconcile is part of the main kubernetes reconciliation loop which aims to
// move the current state of the cluster closer to the desired state.
// the KubernetesServicePatcher object against the actual cluster state, and then
// perform operations to make the cluster state reflect the state specified by
// the user.
//
// For more details, check Reconcile and its Result here:
// - https://pkg.go.dev/sigs.k8s.io/controller-runtime@v0.17.3/pkg/reconcile
func (r *KubernetesServicePatcherReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
	log := r.Log.With("namespace", req.Namespace, "name", req.Name)

	var service corev1.Service
	if err := r.Get(ctx, req.NamespacedName, &service); err != nil {
		log.Error("unable to fetch Service", "error", err)
		return ctrl.Result{}, client.IgnoreNotFound(err)
	}

	if service.Namespace == "default" && service.Name == "kubernetes" && service.Spec.Type == corev1.ServiceTypeClusterIP {
		log.Info("Service has been updated", "service", service.Name, "type", service.Spec.Type)

		originalResourceVersion := service.ResourceVersion

		// Update the service
		service.Spec.Type = corev1.ServiceTypeLoadBalancer

		// Ensure the resource version matches
		service.ResourceVersion = originalResourceVersion

		// Add or update the annotations
		if service.Annotations == nil {
			service.Annotations = make(map[string]string)
		}
		service.Annotations["metallb.universe.tf/allow-shared-ip"] = "192.168.1.50"
		service.Annotations["metallb.universe.tf/loadBalancerIPs"] = "192.168.1.50"

		if err := r.Update(ctx, &service); err != nil {
			log.Error("failed to update Service to LoadBalancer", "error", err)
			return ctrl.Result{}, err
		}

		log.Info("Service has been updated to LoadBalancer", "service", service.Name, "type", service.Spec.Type)
	}

	return ctrl.Result{}, nil
}

// SetupWithManager sets up the controller with the Manager.
func (r *KubernetesServicePatcherReconciler) SetupWithManager(mgr ctrl.Manager) error {
	r.Log = slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{
		Level: slog.LevelInfo,
	}))
	return ctrl.NewControllerManagedBy(mgr).
		For(&corev1.Service{}).
		Complete(r)
}
