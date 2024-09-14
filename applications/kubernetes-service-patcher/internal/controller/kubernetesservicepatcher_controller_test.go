package controller

import (
	"context"
	"log/slog"
	"os"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
	corev1 "k8s.io/api/core/v1"
	"k8s.io/apimachinery/pkg/types"
	"sigs.k8s.io/controller-runtime/pkg/reconcile"
)

var _ = Describe("KubernetesServicePatcher Controller", func() {
	Context("When reconciling a Kubernetes Service resource", func() {
		const (
			serviceName      = "kubernetes"
			serviceNamespace = "default"
		)

		ctx := context.Background()

		typeNamespacedName := types.NamespacedName{
			Name:      serviceName,
			Namespace: serviceNamespace,
		}

		It("should update the Service type to LoadBalancer", func() {
			By("Reconciling the Service resource")
			controllerReconciler := &KubernetesServicePatcherReconciler{
				Client: k8sClient,
				Scheme: k8sClient.Scheme(),
				Log:    slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{Level: slog.LevelInfo})),
			}

			_, err := controllerReconciler.Reconcile(ctx, reconcile.Request{
				NamespacedName: typeNamespacedName,
			})
			Expect(err).NotTo(HaveOccurred())

			service := &corev1.Service{}
			Expect(k8sClient.Get(ctx, typeNamespacedName, service)).To(Succeed())

			By("verifying that the Service type is LoadBalancer")
			Expect(service.Spec.Type).To(Equal(corev1.ServiceTypeLoadBalancer))
			Expect(service.Annotations["metallb.universe.tf/allow-shared-ip"]).To(Equal("192.168.1.50"))
			Expect(service.Annotations["metallb.universe.tf/loadBalancerIPs"]).To(Equal("192.168.1.50"))
		})
	})
})
